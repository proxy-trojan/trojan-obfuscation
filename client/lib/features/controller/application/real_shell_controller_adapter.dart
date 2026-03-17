import 'dart:async';
import 'dart:io';

import '../domain/controller_command.dart';
import '../domain/controller_command_result.dart';
import '../domain/controller_launch_plan.dart';
import '../domain/controller_runtime_config.dart';
import '../domain/controller_runtime_health.dart';
import '../domain/controller_runtime_session.dart';
import '../domain/controller_telemetry_snapshot.dart';
import 'real_shell_connect_planner.dart';
import 'real_shell_runtime_planner.dart';
import 'shell_controller_adapter.dart';
import 'trojan_binary_locator.dart';
import 'trojan_client_config_renderer.dart';

class RealShellControllerAdapter implements ShellControllerAdapter {
  static const Duration _healthProbeTtl = Duration(seconds: 3);
  RealShellControllerAdapter({
    this.binaryPathHint = 'UNCONFIGURED',
    this.transportEndpointHint = 'local-controller://pending',
    this.runtimeMode = 'external-runtime-boundary',
    this.backendKind = 'real-shell-controller-pending',
    this.backendVersion = 'unvalidated',
    RealShellRuntimePlanner? runtimePlanner,
    RealShellConnectPlanner? connectPlanner,
    TrojanClientConfigRenderer? configRenderer,
  })  : _runtimePlanner = runtimePlanner ??
            RealShellRuntimePlanner(
              binaryLocator: TrojanBinaryLocator(
                overrideBinaryPath: binaryPathHint == 'UNCONFIGURED' ||
                        binaryPathHint == 'ENV_UNSET'
                    ? null
                    : binaryPathHint,
              ),
            ),
        _connectPlanner = connectPlanner ?? const RealShellConnectPlanner(),
        _configRenderer = configRenderer ?? const TrojanClientConfigRenderer();

  final String binaryPathHint;
  final String transportEndpointHint;
  final String runtimeMode;
  final String backendKind;
  final String backendVersion;
  final RealShellRuntimePlanner _runtimePlanner;
  final RealShellConnectPlanner _connectPlanner;
  final TrojanClientConfigRenderer _configRenderer;
  static const int _logTailLimit = 30;

  Process? _runningProcess;
  String? _activeConfigPath;
  bool _disconnectRequested = false;
  DateTime? _stopRequestedAt;
  int? _lastExitCode;
  String? _lastError;
  ControllerLaunchPlan? _lastLaunchPlan;
  String? _configProvenance;
  int? _expectedLocalSocksPort;
  ControllerRuntimePhase _runtimePhase = ControllerRuntimePhase.stopped;
  DateTime _sessionUpdatedAt = DateTime.now();
  final List<String> _stdoutTail = <String>[];
  final List<String> _stderrTail = <String>[];
  ControllerRuntimeHealth? _lastProbeHealth;
  DateTime? _lastProbeAt;

  @override
  ControllerTelemetrySnapshot get telemetry => ControllerTelemetrySnapshot(
        backendKind: backendKind,
        backendVersion: backendVersion,
        capabilities: const <String>[
          'connect',
          'disconnect',
          'healthCheck',
          'prepareExport',
        ],
        lastUpdatedAt: DateTime.now(),
      );

  @override
  ControllerRuntimeConfig get runtimeConfig => ControllerRuntimeConfig(
        mode: runtimeMode,
        endpointHint: transportEndpointHint,
        enableVerboseTelemetry: true,
      );

  @override
  ControllerRuntimeSession get session => ControllerRuntimeSession(
        isRunning: _runningProcess != null,
        updatedAt: _sessionUpdatedAt,
        phase: _runtimePhase,
        stopRequested: _disconnectRequested,
        stopRequestedAt: _stopRequestedAt,
        pid: _runningProcess?.pid,
        activeConfigPath: _activeConfigPath,
        configProvenance: _configProvenance,
        expectedLocalSocksPort: _expectedLocalSocksPort,
        launchPlan: _lastLaunchPlan,
        lastExitCode: _lastExitCode,
        lastError: _lastError,
        stdoutTail: List<String>.unmodifiable(_stdoutTail),
        stderrTail: List<String>.unmodifiable(_stderrTail),
      );

  @override
  Future<ControllerRuntimeHealth> checkHealth() async {
    final now = DateTime.now();
    final runningProcess = _runningProcess;
    if (runningProcess != null) {
      final summary = _runtimePhase == ControllerRuntimePhase.sessionReady
          ? 'Trojan runtime is session-ready. pid=${runningProcess.pid} config=${_activeConfigPath ?? 'unknown'}'
          : 'Trojan runtime process is alive. pid=${runningProcess.pid} config=${_activeConfigPath ?? 'unknown'}';
      return ControllerRuntimeHealth(
        level: ControllerRuntimeHealthLevel.healthy,
        summary: summary,
        updatedAt: now,
      );
    }

    final lastProbeAt = _lastProbeAt;
    final lastProbeHealth = _lastProbeHealth;
    if (lastProbeAt != null &&
        lastProbeHealth != null &&
        now.difference(lastProbeAt) < _healthProbeTtl) {
      return lastProbeHealth;
    }

    final plan = _runtimePlanner.buildHealthPlan();
    try {
      final result = await Process.run(plan.binaryPath, plan.arguments);
      final health = result.exitCode == 0
          ? ControllerRuntimeHealth(
              level: ControllerRuntimeHealthLevel.healthy,
              summary: 'Trojan binary probe succeeded via ${plan.binaryPath}.',
              updatedAt: DateTime.now(),
            )
          : ControllerRuntimeHealth(
              level: ControllerRuntimeHealthLevel.degraded,
              summary:
                  'Trojan binary probe exited with code ${result.exitCode} via ${plan.binaryPath}.',
              updatedAt: DateTime.now(),
            );
      _lastProbeAt = DateTime.now();
      _lastProbeHealth = health;
      return health;
    } catch (error) {
      final health = ControllerRuntimeHealth(
        level: ControllerRuntimeHealthLevel.unavailable,
        summary: 'Trojan binary probe failed: $error',
        updatedAt: DateTime.now(),
      );
      _lastProbeAt = DateTime.now();
      _lastProbeHealth = health;
      return health;
    }
  }

  @override
  Future<ControllerCommandResult> execute(ControllerCommand command) async {
    switch (command.kind) {
      case ControllerCommandKind.connect:
        return _planConnect(command);
      case ControllerCommandKind.disconnect:
        return _disconnect(command);
      case ControllerCommandKind.collectDiagnostics:
      case ControllerCommandKind.prepareExport:
        return ControllerCommandResult(
          commandId: command.id,
          accepted: false,
          completedAt: DateTime.now(),
          summary:
              'Command kind ${command.kind.name} is not wired in the real shell adapter yet.',
          error: 'NOT_IMPLEMENTED',
        );
    }
  }

  Future<ControllerCommandResult> _disconnect(ControllerCommand command) async {
    final process = _runningProcess;
    if (process == null) {
      return ControllerCommandResult(
        commandId: command.id,
        accepted: false,
        completedAt: DateTime.now(),
        summary:
            'No running trojan client process is attached to the real shell adapter.',
        error: 'NO_RUNNING_PROCESS',
      );
    }

    final configPath = _activeConfigPath;
    final killed = process.kill();
    if (killed) {
      _disconnectRequested = true;
      _stopRequestedAt = DateTime.now();
      _markSessionUpdated();
      return ControllerCommandResult(
        commandId: command.id,
        accepted: true,
        completedAt: DateTime.now(),
        summary: 'Requested trojan client shutdown for pid=${process.pid}.',
        details: <String, Object?>{
          'pid': process.pid,
          'configPath': configPath,
        },
      );
    }

    return ControllerCommandResult(
      commandId: command.id,
      accepted: false,
      completedAt: DateTime.now(),
      summary: 'Failed to terminate trojan client pid=${process.pid}.',
      error: 'KILL_FAILED',
    );
  }

  Future<ControllerCommandResult> _planConnect(
      ControllerCommand command) async {
    final input = _connectPlanner.parse(command);
    if (input == null) {
      return ControllerCommandResult(
        commandId: command.id,
        accepted: false,
        completedAt: DateTime.now(),
        summary:
            'Missing required connect inputs for real shell controller planning.',
        error: 'MISSING_CONNECT_INPUTS',
      );
    }

    if (_runningProcess != null) {
      return ControllerCommandResult(
        commandId: command.id,
        accepted: false,
        completedAt: DateTime.now(),
        summary:
            'A trojan client process is already running under this adapter.',
        error: 'PROCESS_ALREADY_RUNNING',
        details: <String, Object?>{
          'pid': _runningProcess!.pid,
          'configPath': _activeConfigPath,
        },
      );
    }

    _prepareFreshSessionForConnect();

    final plan = _runtimePlanner.buildConnectPlan(
      profile: input.profile,
      configPath: input.configPath,
    );
    _lastLaunchPlan = plan;
    _activeConfigPath = input.configPath;
    _configProvenance = 'managed-runtime://${input.profile.id}';
    _expectedLocalSocksPort = input.profile.localSocksPort;
    _runtimePhase = ControllerRuntimePhase.planned;
    _markSessionUpdated();

    final configPreview = _configRenderer.render(
      profile: input.profile,
      password: input.password,
    );
    final configPreviewRedacted = _configRenderer.render(
      profile: input.profile,
      password: 'REDACTED',
    );

    try {
      final configFile = File(input.configPath);
      await configFile.parent.create(recursive: true);
      await configFile.writeAsString(configPreview, flush: true);

      // 设置配置文件权限为仅所有者可读写，防止明文密码泄露
      if (!Platform.isWindows) {
        await Process.run('chmod', <String>['600', input.configPath]);
      }

      _runtimePhase = ControllerRuntimePhase.launching;
      _markSessionUpdated();

      final process = await Process.start(plan.binaryPath, plan.arguments);
      _runningProcess = process;
      _activeConfigPath = input.configPath;
      _lastError = null;
      _lastExitCode = null;
      _runtimePhase = ControllerRuntimePhase.alive;
      _markSessionUpdated();

      unawaited(_promoteSessionReadyWhenPortOpens(process));

      process.stdout
          .transform(const SystemEncoding().decoder)
          .listen((chunk) => _appendLogLines(_stdoutTail, chunk));
      process.stderr
          .transform(const SystemEncoding().decoder)
          .listen((chunk) => _appendLogLines(_stderrTail, chunk));
      process.exitCode.then((exitCode) async {
        final disconnectRequested = _disconnectRequested;
        _lastExitCode = exitCode;
        if (disconnectRequested) {
          // disconnect path should be treated as user-requested teardown,
          // not as runtime failure noise.
          _lastError = null;
        }
        if (disconnectRequested) {
          _runtimePhase = ControllerRuntimePhase.stopped;
        } else if (exitCode == 0) {
          _runtimePhase = ControllerRuntimePhase.stopped;
        } else {
          _runtimePhase = ControllerRuntimePhase.failed;
        }
        _markSessionUpdated();
        if (identical(_runningProcess, process)) {
          final configPath = _activeConfigPath;
          _runningProcess = null;
          _activeConfigPath = null;
          _disconnectRequested = false;
          _stopRequestedAt = null;
          _markSessionUpdated();
          await _cleanupConfigFile(configPath);
          await _cleanupRuntimeDirectoryIfEmpty(configPath);
        }
      });

      return ControllerCommandResult(
        commandId: command.id,
        accepted: true,
        completedAt: DateTime.now(),
        summary:
            'Started trojan client process pid=${process.pid} using ${plan.binaryPath}.',
        details: <String, Object?>{
          'pid': process.pid,
          'launchPlan': plan.toJson(),
          'runtimePhase': _runtimePhase.name,
          'configPath': input.configPath,
          'configProvenance': _configProvenance,
          'expectedLocalSocksPort': _expectedLocalSocksPort,
          'configPreview': configPreviewRedacted,
        },
      );
    } catch (error) {
      _lastError = error.toString();
      _runtimePhase = ControllerRuntimePhase.failed;
      _markSessionUpdated();
      await _cleanupConfigFile(input.configPath);
      await _cleanupRuntimeDirectoryIfEmpty(input.configPath);
      return ControllerCommandResult(
        commandId: command.id,
        accepted: false,
        completedAt: DateTime.now(),
        summary: 'Failed to execute trojan client launch plan.',
        error: error.toString(),
        details: <String, Object?>{
          'launchPlan': plan.toJson(),
          'runtimePhase': _runtimePhase.name,
          'configPath': input.configPath,
          'configProvenance': _configProvenance,
          'expectedLocalSocksPort': _expectedLocalSocksPort,
          'configPreview': configPreviewRedacted,
        },
      );
    }
  }

  void _prepareFreshSessionForConnect() {
    _disconnectRequested = false;
    _stopRequestedAt = null;
    _lastError = null;
    _lastExitCode = null;
    _runtimePhase = ControllerRuntimePhase.stopped;
    _stdoutTail.clear();
    _stderrTail.clear();
    _markSessionUpdated();
  }

  Future<void> _cleanupConfigFile(String? configPath) async {
    if (configPath == null || configPath.trim().isEmpty) return;
    final file = File(configPath);
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (error) {
      _lastError = 'CONFIG_CLEANUP_FAILED: $error';
      _markSessionUpdated();
    }
  }

  Future<void> _cleanupRuntimeDirectoryIfEmpty(String? configPath) async {
    if (configPath == null || configPath.trim().isEmpty) return;
    try {
      final directory = File(configPath).parent;
      if (!await directory.exists()) return;
      final entries = await directory.list().toList();
      if (entries.isEmpty) {
        await directory.delete();
      }
    } catch (_) {
      // keep best-effort cleanup non-blocking
    }
  }

  Future<void> _promoteSessionReadyWhenPortOpens(Process process) async {
    final expectedPort = _expectedLocalSocksPort;
    if (expectedPort == null || expectedPort <= 0) return;

    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (DateTime.now().isBefore(deadline)) {
      if (!identical(_runningProcess, process)) return;

      final isOpen = await _isLocalPortOpen(expectedPort);
      if (isOpen) {
        _runtimePhase = ControllerRuntimePhase.sessionReady;
        _markSessionUpdated();
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
  }

  Future<bool> _isLocalPortOpen(int port) async {
    Socket? socket;
    try {
      socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
        timeout: const Duration(milliseconds: 200),
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      socket?.destroy();
    }
  }

  void _appendLogLines(List<String> target, String chunk) {
    final lines = chunk
        .split('\n')
        .map((line) => line.trimRight())
        .where((line) => line.isNotEmpty);
    var changed = false;
    for (final line in lines) {
      target.add(line);
      changed = true;
    }
    if (target.length > _logTailLimit) {
      target.removeRange(0, target.length - _logTailLimit);
      changed = true;
    }
    if (changed) {
      _markSessionUpdated();
    }
  }

  void _markSessionUpdated() {
    _sessionUpdatedAt = DateTime.now();
  }
}
