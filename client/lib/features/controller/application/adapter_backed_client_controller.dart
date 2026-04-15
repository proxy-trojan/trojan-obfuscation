import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../platform/services/client_filesystem_layout.dart';
import '../../../platform/services/local_state_store.dart';
import '../../profiles/application/profile_secrets_service.dart';
import '../../profiles/domain/client_profile.dart';
import '../../routing/application/routing_profile_codec.dart';
import '../domain/client_connection_status.dart';
import '../domain/client_controller_event.dart';
import '../domain/controller_command.dart';
import '../domain/controller_command_result.dart';
import '../domain/controller_runtime_config.dart';
import '../domain/controller_runtime_health.dart';
import '../domain/controller_runtime_session.dart';
import '../domain/controller_telemetry_snapshot.dart';
import '../domain/failure_family.dart';
import '../domain/last_runtime_failure_summary.dart';
import 'client_controller_api.dart';
import 'shell_controller_adapter.dart';

class AdapterBackedClientController extends ClientControllerApi {
  AdapterBackedClientController({
    required ShellControllerAdapter adapter,
    required ProfileSecretsService profileSecrets,
    LocalStateStore? localStateStore,
    ClientFilesystemLayout? filesystemLayout,
    RoutingProfileCodec? routingCodec,
    Duration sessionPollInterval = const Duration(milliseconds: 600),
  })  : _adapter = adapter,
        _profileSecrets = profileSecrets,
        _localStateStore = localStateStore,
        _filesystemLayout = filesystemLayout,
        _routingCodec = routingCodec ?? const RoutingProfileCodec() {
    _lastSessionUpdatedAt = _adapter.session.updatedAt;
    _sessionWatcher = Timer.periodic(sessionPollInterval, (_) {
      final session = _adapter.session;
      final updatedAt = session.updatedAt;
      if (_lastSessionUpdatedAt != updatedAt) {
        _lastSessionUpdatedAt = updatedAt;
        _reconcileStatusWithSession(session);
        _notifyIfActive();
      }
    });
  }

  static const int _maxEvents = 12;
  static const String _lastRuntimeFailureKey =
      'controller.lastRuntimeFailureSummary';
  static const String _runtimeSnapshotKey = 'controller.runtimeSessionSnapshot';

  final ShellControllerAdapter _adapter;
  final ProfileSecretsService _profileSecrets;
  final LocalStateStore? _localStateStore;
  final ClientFilesystemLayout? _filesystemLayout;
  final RoutingProfileCodec _routingCodec;
  late final Timer _sessionWatcher;
  DateTime? _lastSessionUpdatedAt;
  int _operationCounter = 0;
  int _eventCounter = 0;
  bool _disposed = false;
  bool _operationInProgress = false;
  ClientConnectionStatus _status = ClientConnectionStatus.disconnected();
  LastRuntimeFailureSummary? _lastRuntimeFailure;
  final List<ClientControllerEvent> _events = <ClientControllerEvent>[
    ClientControllerEvent(
      id: 'boot',
      timestamp: DateTime.now(),
      title: 'Client shell ready',
      message: 'Adapter-backed controller boundary initialized.',
      phase: ClientConnectionPhase.disconnected,
      kind: ClientControllerEventKind.lifecycle,
    ),
  ];

  @override
  ClientConnectionStatus get status => _status;

  @override
  List<ClientControllerEvent> get recentEvents =>
      List<ClientControllerEvent>.unmodifiable(_events);

  @override
  ControllerTelemetrySnapshot get telemetry => _adapter.telemetry;

  @override
  ControllerRuntimeConfig get runtimeConfig => _adapter.runtimeConfig;

  @override
  ControllerRuntimeSession get session => _adapter.session;

  @override
  LastRuntimeFailureSummary? get lastRuntimeFailure => _lastRuntimeFailure;

  Future<void> restorePersistedState() async {
    final store = _localStateStore;
    if (store == null) return;

    var changed = false;
    final restoredFailure = await _readLastRuntimeFailure(store);
    if (restoredFailure != null) {
      _lastRuntimeFailure = restoredFailure;
      changed = true;
    }

    final snapshot = await _readRuntimeSnapshot(store);
    if (snapshot != null &&
        _shouldRecoverFromSnapshot(snapshot, _adapter.session)) {
      await _cleanupRecoveredRuntimeArtifacts(snapshot);
      final recoveryMessage = _buildRecoveryMessage(snapshot.activeProfileId);
      _status = ClientConnectionStatus(
        phase: ClientConnectionPhase.error,
        message: recoveryMessage,
        updatedAt: DateTime.now(),
        activeProfileId: snapshot.activeProfileId,
        errorCode: 'RUNTIME_RECOVERY_INTERRUPTED_SESSION',
        failureFamilyHint: FailureFamily.launch.label,
      );
      _recordEvent(
        title: 'Recovered interrupted session state',
        message: recoveryMessage,
        phase: ClientConnectionPhase.error,
        profileId: snapshot.activeProfileId,
        kind: ClientControllerEventKind.lifecycle,
        level: ClientControllerEventLevel.warning,
      );
      await _recordLastRuntimeFailure(
        profileId: snapshot.activeProfileId,
        phase: 'recovery',
        headline: 'Recovered from interrupted runtime state',
        detail: recoveryMessage,
        summary: recoveryMessage,
      );
      await _persistRuntimeSnapshot();
      changed = true;
    }

    if (changed) {
      _notifyIfActive();
    }
  }

  @override
  Future<ControllerRuntimeHealth> checkHealth() => _adapter.checkHealth();

  @override
  Future<ControllerCommandResult> collectDiagnostics({
    required String bundleKind,
  }) {
    return _adapter.execute(
      ControllerCommand(
        id: 'collect-diagnostics-${++_operationCounter}',
        kind: ControllerCommandKind.collectDiagnostics,
        issuedAt: DateTime.now(),
        profileId: _status.activeProfileId,
        arguments: <String, Object?>{
          'bundleKind': bundleKind,
        },
      ),
    );
  }

  @override
  Future<ControllerCommandResult> prepareExport({
    required String bundleKind,
  }) {
    return _adapter.execute(
      ControllerCommand(
        id: 'prepare-export-${++_operationCounter}',
        kind: ControllerCommandKind.prepareExport,
        issuedAt: DateTime.now(),
        profileId: _status.activeProfileId,
        arguments: <String, Object?>{
          'bundleKind': bundleKind,
        },
      ),
    );
  }

  @override
  Future<ControllerCommandResult> connect(ClientProfile profile) async {
    if (_operationInProgress) {
      return ControllerCommandResult(
        commandId: 'connect-rejected',
        accepted: false,
        completedAt: DateTime.now(),
        summary: '另一个连接/断开操作正在进行中，请稍后重试。',
        error: 'OPERATION_IN_PROGRESS',
      );
    }
    _operationInProgress = true;
    try {
      return await _connectInner(profile);
    } finally {
      _operationInProgress = false;
    }
  }

  Future<ControllerCommandResult> _connectInner(ClientProfile profile) async {
    final operationId = 'connect-${++_operationCounter}';
    final password = await _profileSecrets.readTrojanPassword(profile.id);
    if (password == null || password.trim().isEmpty) {
      final result = ControllerCommandResult(
        commandId: operationId,
        accepted: false,
        completedAt: DateTime.now(),
        summary:
            'Cannot prepare connect plan because no Trojan password is stored for ${profile.name}.',
        error: 'MISSING_TROJAN_PASSWORD',
      );
      _recordEvent(
        title: 'Connect blocked',
        message: result.summary,
        phase: ClientConnectionPhase.error,
        profileId: profile.id,
        kind: ClientControllerEventKind.result,
        operationId: operationId,
        step: 1,
        level: ClientControllerEventLevel.error,
      );
      _status = ClientConnectionStatus(
        phase: ClientConnectionPhase.error,
        message: result.error ?? result.summary,
        updatedAt: DateTime.now(),
        activeProfileId: profile.id,
        errorCode: result.error,
        failureFamilyHint: FailureFamily.userInput.label,
      );
      await _persistRuntimeSnapshot();
      _notifyIfActive();
      return result;
    }

    final commandResult = await _adapter.execute(
      ControllerCommand(
        id: operationId,
        kind: ControllerCommandKind.connect,
        issuedAt: DateTime.now(),
        profileId: profile.id,
        arguments: <String, Object?>{
          'profileName': profile.name,
          'serverHost': profile.serverHost,
          'serverPort': profile.serverPort,
          'localSocksPort': profile.localSocksPort,
          'sni': profile.sni,
          'verifyTls': profile.verifyTls,
          'configPath': _configPathFor(profile.id),
          'routing': _routingCodec.encodeToJsonMap(profile.routing),
        },
        secretArguments: <String, String>{
          'trojanPassword': password,
        },
      ),
    );

    final runtimeMode = runtimeConfig.mode;
    final runtimeSession = _adapter.session;
    final acceptedPhase = _acceptedPhaseForConnect(
      runtimeMode: runtimeMode,
      runtimeSession: runtimeSession,
      commandResult: commandResult,
    );
    final acceptedMessage = _acceptedMessageForConnect(
      runtimeMode: runtimeMode,
      runtimeSession: runtimeSession,
      commandResult: commandResult,
    );

    _recordEvent(
      title: 'Connect requested',
      message: commandResult.accepted ? acceptedMessage : commandResult.summary,
      phase:
          commandResult.accepted ? acceptedPhase : ClientConnectionPhase.error,
      profileId: profile.id,
      kind: ClientControllerEventKind.action,
      operationId: operationId,
      step: 1,
      level: commandResult.accepted
          ? ClientControllerEventLevel.info
          : ClientControllerEventLevel.error,
    );

    if (!commandResult.accepted) {
      _status = ClientConnectionStatus(
        phase: ClientConnectionPhase.error,
        message: commandResult.error ?? commandResult.summary,
        updatedAt: DateTime.now(),
        activeProfileId: profile.id,
        errorCode: commandResult.error,
        failureFamilyHint: classifyFailureFamily(
          errorCode: commandResult.error,
          summary: commandResult.summary,
          detail: commandResult.error ?? commandResult.summary,
          phase: 'launch',
        ).label,
      );
      await _recordLastRuntimeFailure(
        profileId: profile.id,
        phase: 'launch',
        headline: 'The connection could not start',
        detail: commandResult.error ?? commandResult.summary,
        errorCode: commandResult.error,
        summary: commandResult.summary,
      );
      await _persistRuntimeSnapshot();
      _notifyIfActive();
      return commandResult;
    }

    _status = ClientConnectionStatus(
      phase: acceptedPhase,
      message: acceptedMessage,
      updatedAt: DateTime.now(),
      activeProfileId: profile.id,
    );
    await _clearLastRuntimeFailure();
    await _persistRuntimeSnapshot();
    _notifyIfActive();
    return commandResult;
  }

  @override
  Future<ControllerCommandResult> disconnect() async {
    if (_operationInProgress) {
      return ControllerCommandResult(
        commandId: 'disconnect-rejected',
        accepted: false,
        completedAt: DateTime.now(),
        summary: '另一个连接/断开操作正在进行中，请稍后重试。',
        error: 'OPERATION_IN_PROGRESS',
      );
    }
    _operationInProgress = true;
    try {
      return await _disconnectInner();
    } finally {
      _operationInProgress = false;
    }
  }

  Future<ControllerCommandResult> _disconnectInner() async {
    final operationId = 'disconnect-${++_operationCounter}';
    final activeProfileId = _status.activeProfileId;

    _status = ClientConnectionStatus(
      phase: ClientConnectionPhase.disconnecting,
      message: 'Disconnecting current session...',
      updatedAt: DateTime.now(),
      activeProfileId: activeProfileId,
    );
    await _persistRuntimeSnapshot();
    _notifyIfActive();

    final commandResult = await _adapter.execute(
      ControllerCommand(
        id: operationId,
        kind: ControllerCommandKind.disconnect,
        issuedAt: DateTime.now(),
        profileId: activeProfileId,
      ),
    );

    if (!commandResult.accepted) {
      _recordEvent(
        title: 'Disconnect requested',
        message: commandResult.summary,
        phase: ClientConnectionPhase.error,
        profileId: activeProfileId,
        kind: ClientControllerEventKind.result,
        operationId: operationId,
        step: 1,
        level: ClientControllerEventLevel.error,
      );
      _status = ClientConnectionStatus(
        phase: ClientConnectionPhase.error,
        message: commandResult.error ?? commandResult.summary,
        updatedAt: DateTime.now(),
        activeProfileId: activeProfileId,
        errorCode: commandResult.error,
        failureFamilyHint: classifyFailureFamily(
          errorCode: commandResult.error,
          summary: commandResult.summary,
          detail: commandResult.error ?? commandResult.summary,
          phase: 'disconnect',
        ).label,
      );
      await _recordLastRuntimeFailure(
        profileId: activeProfileId,
        phase: 'disconnect',
        headline: 'The session could not be disconnected cleanly',
        detail: commandResult.error ?? commandResult.summary,
        errorCode: commandResult.error,
        summary: commandResult.summary,
      );
      await _persistRuntimeSnapshot();
      _notifyIfActive();
      return commandResult;
    }

    final runtimeSession = _adapter.session;
    final runningAfterRequest = runtimeSession.isRunning;
    final nextPhase = runningAfterRequest
        ? ClientConnectionPhase.disconnecting
        : ClientConnectionPhase.disconnected;
    final nextMessage = runningAfterRequest
        ? _disconnectPendingMessage(runtimeSession, commandResult)
        : commandResult.summary;

    _recordEvent(
      title: 'Disconnect requested',
      message: nextMessage,
      phase: nextPhase,
      profileId: activeProfileId,
      kind: ClientControllerEventKind.result,
      operationId: operationId,
      step: 1,
      level: ClientControllerEventLevel.info,
    );

    _status = nextPhase == ClientConnectionPhase.disconnected
        ? ClientConnectionStatus(
            phase: ClientConnectionPhase.disconnected,
            message: nextMessage,
            updatedAt: DateTime.now(),
          )
        : ClientConnectionStatus(
            phase: ClientConnectionPhase.disconnecting,
            message: nextMessage,
            updatedAt: DateTime.now(),
            activeProfileId: activeProfileId,
          );

    if (nextPhase == ClientConnectionPhase.disconnected) {
      await _clearLastRuntimeFailure();
    }
    await _persistRuntimeSnapshot();
    _notifyIfActive();
    return commandResult;
  }

  ClientConnectionPhase _acceptedPhaseForConnect({
    required String runtimeMode,
    required ControllerRuntimeSession runtimeSession,
    required ControllerCommandResult commandResult,
  }) {
    if (runtimeMode.startsWith('stubbed-local-boundary')) {
      return ClientConnectionPhase.connected;
    }

    if (commandResult.details.containsKey('pid') &&
        runtimeSession.phase == ControllerRuntimePhase.sessionReady) {
      return ClientConnectionPhase.connected;
    }

    return ClientConnectionPhase.connecting;
  }

  String _acceptedMessageForConnect({
    required String runtimeMode,
    required ControllerRuntimeSession runtimeSession,
    required ControllerCommandResult commandResult,
  }) {
    if (runtimeMode.startsWith('stubbed-local-boundary')) {
      return commandResult.summary;
    }

    return switch (runtimeSession.phase) {
      ControllerRuntimePhase.planned =>
        'Launch plan accepted. Preparing managed runtime config.',
      ControllerRuntimePhase.launching =>
        'Launch plan accepted. Starting runtime process.',
      ControllerRuntimePhase.alive =>
        'Runtime process is alive. Waiting for session-ready signal.',
      ControllerRuntimePhase.sessionReady => commandResult.summary,
      ControllerRuntimePhase.failed => commandResult.summary,
      ControllerRuntimePhase.stopped =>
        'Launch accepted. Waiting for runtime state update.',
    };
  }

  String _disconnectPendingMessage(
    ControllerRuntimeSession runtimeSession,
    ControllerCommandResult commandResult,
  ) {
    final pidSuffix =
        runtimeSession.pid == null ? '' : ' (pid=${runtimeSession.pid})';
    if (runtimeSession.stopRequested) {
      return 'Stop requested$pidSuffix. Waiting for the runtime process to exit cleanly.';
    }
    return commandResult.summary;
  }

  String _configPathFor(String profileId) {
    final safeProfileId = profileId.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return '$_managedRuntimeDirectoryPath${Platform.pathSeparator}runtime-profile-$safeProfileId.json';
  }

  @override
  void dispose() {
    _disposed = true;
    _sessionWatcher.cancel();
    super.dispose();
  }

  void _reconcileStatusWithSession(ControllerRuntimeSession session) {
    final activeProfileId = _status.activeProfileId;

    if (session.isRunning) {
      if (_status.phase == ClientConnectionPhase.connecting) {
        if (session.phase == ControllerRuntimePhase.sessionReady) {
          final summary = session.pid == null
              ? 'Runtime session is ready.'
              : 'Runtime session is ready. pid=${session.pid}';
          _status = _status.copyWith(
            phase: ClientConnectionPhase.connected,
            message: summary,
            updatedAt: DateTime.now(),
            clearErrorCode: true,
            clearFailureFamilyHint: true,
          );
          _recordEvent(
            title: 'Runtime session ready',
            message: summary,
            phase: ClientConnectionPhase.connected,
            profileId: _status.activeProfileId,
            kind: ClientControllerEventKind.progress,
            level: ClientControllerEventLevel.info,
          );
          _clearLastRuntimeFailureSoon();
          _persistRuntimeSnapshotSoon();
          return;
        }

        final progressSummary = switch (session.phase) {
          ControllerRuntimePhase.planned =>
            'Launch plan prepared. Writing managed runtime config.',
          ControllerRuntimePhase.launching =>
            'Managed runtime is launching now.',
          ControllerRuntimePhase.alive => session.pid == null
              ? 'Runtime process is alive. Waiting for session-ready signal.'
              : 'Runtime process is alive (pid=${session.pid}). Waiting for session-ready signal.',
          ControllerRuntimePhase.failed =>
            'Runtime launch reported a failure state.',
          ControllerRuntimePhase.stopped =>
            'Launch accepted. Waiting for runtime process to start.',
          ControllerRuntimePhase.sessionReady => 'Runtime session is ready.',
        };

        if (_status.message != progressSummary) {
          _status = _status.copyWith(
            phase: ClientConnectionPhase.connecting,
            message: progressSummary,
            updatedAt: DateTime.now(),
            clearErrorCode: true,
            clearFailureFamilyHint: true,
          );
          _recordEvent(
            title: 'Runtime launch in progress',
            message: progressSummary,
            phase: ClientConnectionPhase.connecting,
            profileId: _status.activeProfileId,
            kind: ClientControllerEventKind.progress,
            level: ClientControllerEventLevel.info,
          );
          _persistRuntimeSnapshotSoon();
        }
      }

      if (_status.phase == ClientConnectionPhase.disconnecting) {
        final stopSummary = session.stopRequested
            ? 'Stop requested${session.pid == null ? '' : ' (pid=${session.pid})'}. Waiting for the runtime process to exit cleanly.'
            : 'Disconnect requested. Waiting for the runtime process to exit.';
        if (_status.message != stopSummary) {
          _status = _status.copyWith(
            phase: ClientConnectionPhase.disconnecting,
            message: stopSummary,
            updatedAt: DateTime.now(),
            clearErrorCode: true,
            clearFailureFamilyHint: true,
          );
          _recordEvent(
            title: 'Runtime stop in progress',
            message: stopSummary,
            phase: ClientConnectionPhase.disconnecting,
            profileId: _status.activeProfileId,
            kind: ClientControllerEventKind.progress,
            level: ClientControllerEventLevel.info,
          );
          _persistRuntimeSnapshotSoon();
        }
      }
      return;
    }

    if (_status.phase != ClientConnectionPhase.connected &&
        _status.phase != ClientConnectionPhase.connecting &&
        _status.phase != ClientConnectionPhase.disconnecting) {
      return;
    }

    final lastError = session.lastError?.trim();
    final lastExitCode = session.lastExitCode;

    if (_status.phase == ClientConnectionPhase.disconnecting) {
      final hadAbnormalExit = (lastError != null && lastError.isNotEmpty) ||
          (lastExitCode != null && lastExitCode != 0);
      final summary = lastError != null && lastError.isNotEmpty
          ? 'Runtime session ended after disconnect request (last runtime detail: $lastError).'
          : (lastExitCode != null && lastExitCode != 0)
              ? 'Runtime session ended after disconnect request (exit code $lastExitCode).'
              : (lastExitCode == 0
                  ? 'Runtime session ended cleanly.'
                  : 'Runtime session is no longer running.');
      _status = ClientConnectionStatus(
        phase: ClientConnectionPhase.disconnected,
        message: summary,
        updatedAt: DateTime.now(),
      );
      _recordEvent(
        title: 'Disconnect completed',
        message: summary,
        phase: ClientConnectionPhase.disconnected,
        profileId: null,
        kind: ClientControllerEventKind.result,
        level: hadAbnormalExit
            ? ClientControllerEventLevel.warning
            : ClientControllerEventLevel.info,
      );
      _clearLastRuntimeFailureSoon();
      _persistRuntimeSnapshotSoon();
      return;
    }

    if (lastError != null && lastError.isNotEmpty) {
      final summary = 'Runtime session stopped with error: $lastError';
      _status = ClientConnectionStatus(
        phase: ClientConnectionPhase.error,
        message: summary,
        updatedAt: DateTime.now(),
        activeProfileId: activeProfileId,
        errorCode: 'RUNTIME_SESSION_ERROR',
        failureFamilyHint: FailureFamily.connect.label,
      );
      _recordEvent(
        title: 'Runtime session ended',
        message: summary,
        phase: ClientConnectionPhase.error,
        profileId: activeProfileId,
        kind: ClientControllerEventKind.result,
        level: ClientControllerEventLevel.error,
      );
      _recordLastRuntimeFailureSoon(
        profileId: activeProfileId,
        phase: 'runtime',
        headline: 'The runtime session stopped unexpectedly',
        detail: lastError,
        summary: summary,
      );
      _persistRuntimeSnapshotSoon();
      return;
    }

    if (lastExitCode != null && lastExitCode != 0) {
      final summary = 'Runtime session exited with code $lastExitCode.';
      _status = ClientConnectionStatus(
        phase: ClientConnectionPhase.error,
        message: summary,
        updatedAt: DateTime.now(),
        activeProfileId: activeProfileId,
        errorCode: 'RUNTIME_SESSION_EXIT_NONZERO',
        failureFamilyHint: FailureFamily.connect.label,
      );
      _recordEvent(
        title: 'Runtime session ended',
        message: summary,
        phase: ClientConnectionPhase.error,
        profileId: activeProfileId,
        kind: ClientControllerEventKind.result,
        level: ClientControllerEventLevel.error,
      );
      _recordLastRuntimeFailureSoon(
        profileId: activeProfileId,
        phase: 'runtime',
        headline: 'The runtime session exited unexpectedly',
        detail: 'Exit code $lastExitCode',
        summary: summary,
      );
      _persistRuntimeSnapshotSoon();
      return;
    }

    final summary = lastExitCode == 0
        ? 'Runtime session ended cleanly.'
        : 'Runtime session is no longer running.';
    _status = ClientConnectionStatus(
      phase: ClientConnectionPhase.disconnected,
      message: summary,
      updatedAt: DateTime.now(),
    );
    _recordEvent(
      title: 'Runtime session ended',
      message: summary,
      phase: ClientConnectionPhase.disconnected,
      profileId: null,
      kind: ClientControllerEventKind.result,
      level: ClientControllerEventLevel.warning,
    );
    _clearLastRuntimeFailureSoon();
    _persistRuntimeSnapshotSoon();
  }

  Future<void> _recordLastRuntimeFailure({
    required String? profileId,
    required String phase,
    required String headline,
    required String detail,
    String? errorCode,
    String? summary,
  }) async {
    _lastRuntimeFailure = LastRuntimeFailureSummary(
      profileId: profileId,
      phase: phase,
      family: classifyFailureFamily(
        errorCode: errorCode,
        summary: summary,
        detail: detail,
        phase: phase,
      ),
      headline: headline,
      detail: detail,
      recordedAt: DateTime.now(),
    );
    await _persistLastRuntimeFailure();
  }

  void _recordLastRuntimeFailureSoon({
    required String? profileId,
    required String phase,
    required String headline,
    required String detail,
    String? errorCode,
    String? summary,
  }) {
    unawaited(
      _recordLastRuntimeFailure(
        profileId: profileId,
        phase: phase,
        headline: headline,
        detail: detail,
        errorCode: errorCode,
        summary: summary,
      ).then((_) => _notifyIfActive()),
    );
  }

  Future<void> _clearLastRuntimeFailure() async {
    if (_lastRuntimeFailure == null) return;
    _lastRuntimeFailure = null;
    await _persistLastRuntimeFailure();
  }

  void _clearLastRuntimeFailureSoon() {
    unawaited(_clearLastRuntimeFailure().then((_) => _notifyIfActive()));
  }

  Future<void> _persistLastRuntimeFailure() async {
    final store = _localStateStore;
    if (store == null) return;
    try {
      final failure = _lastRuntimeFailure;
      if (failure == null) {
        await store.delete(_lastRuntimeFailureKey);
      } else {
        await store.write(_lastRuntimeFailureKey, jsonEncode(failure.toJson()));
      }
    } catch (_) {
      // best-effort persistence: keep runtime flow non-blocking on storage failures
    }
  }

  Future<void> _persistRuntimeSnapshot() async {
    final store = _localStateStore;
    if (store == null) return;
    final currentSession = _adapter.session;
    final snapshot = _PersistedRuntimeSnapshot(
      statusPhase: _status.phase.name,
      statusMessage: _status.message,
      activeProfileId: _status.activeProfileId,
      statusUpdatedAt: _status.updatedAt,
      sessionPhase: currentSession.phase.name,
      sessionIsRunning: currentSession.isRunning,
      sessionStopRequested: currentSession.stopRequested,
      sessionStopRequestedAt: currentSession.stopRequestedAt,
      sessionPid: currentSession.pid,
      sessionActiveConfigPath: currentSession.activeConfigPath,
      sessionConfigProvenance: currentSession.configProvenance,
      sessionExpectedLocalSocksPort: currentSession.expectedLocalSocksPort,
      sessionLaunchPlanSummary: currentSession.launchPlan?.summary,
      sessionLastExitCode: currentSession.lastExitCode,
      sessionLastError: currentSession.lastError,
      sessionUpdatedAt: currentSession.updatedAt,
    );
    try {
      await store.write(_runtimeSnapshotKey, jsonEncode(snapshot.toJson()));
    } catch (_) {
      // best-effort persistence: keep runtime flow non-blocking on storage failures
    }
  }

  void _persistRuntimeSnapshotSoon() {
    unawaited(_persistRuntimeSnapshot());
  }

  Future<LastRuntimeFailureSummary?> _readLastRuntimeFailure(
    LocalStateStore store,
  ) async {
    final raw = await store.read(_lastRuntimeFailureKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return LastRuntimeFailureSummary.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<_PersistedRuntimeSnapshot?> _readRuntimeSnapshot(
    LocalStateStore store,
  ) async {
    final raw = await store.read(_runtimeSnapshotKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return _PersistedRuntimeSnapshot.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> _cleanupRecoveredRuntimeArtifacts(
    _PersistedRuntimeSnapshot snapshot,
  ) async {
    final configPath = snapshot.sessionActiveConfigPath;
    if (configPath == null || configPath.trim().isEmpty) return;
    if (!_isWithinManagedRuntimeDirectory(configPath)) return;

    try {
      final file = File(configPath);
      if (await file.exists()) {
        await file.delete();
      }
      await _cleanupRuntimeDirectoryIfEmpty();
    } catch (_) {
      // best-effort cleanup: recovery must not fail hard because of file ops
    }
  }

  Future<void> _cleanupRuntimeDirectoryIfEmpty() async {
    final runtimeDirectoryPath = _managedRuntimeDirectoryPath;
    final directory = Directory(runtimeDirectoryPath);
    if (!await directory.exists()) return;

    try {
      final entries = await directory.list().toList();
      if (entries.isEmpty) {
        await directory.delete();
      }
    } catch (_) {
      // ignore cleanup failures: stale empty folder is acceptable
    }
  }

  String get _managedRuntimeDirectoryPath {
    final baseDirectory =
        _filesystemLayout?.stateDirectoryPath ?? Directory.systemTemp.path;
    return '$baseDirectory${Platform.pathSeparator}runtime';
  }

  bool _isWithinManagedRuntimeDirectory(String candidatePath) {
    final runtimeRoot = _normalizePathForCompare(
        Directory(_managedRuntimeDirectoryPath).absolute.path);
    final candidate =
        _normalizePathForCompare(File(candidatePath).absolute.path);
    final prefix = runtimeRoot.endsWith('/') ? runtimeRoot : '$runtimeRoot/';
    return candidate.startsWith(prefix);
  }

  String _normalizePathForCompare(String path) {
    final normalized = path.replaceAll('\\', '/');
    if (Platform.isWindows) {
      return normalized.toLowerCase();
    }
    return normalized;
  }

  bool _shouldRecoverFromSnapshot(
    _PersistedRuntimeSnapshot snapshot,
    ControllerRuntimeSession liveSession,
  ) {
    if (liveSession.isRunning) return false;
    final snapshotPhase = _phaseFromName(snapshot.statusPhase);
    if (snapshotPhase == null) return false;

    final snapshotSuggestsActiveSession = snapshot.sessionIsRunning ||
        snapshotPhase == ClientConnectionPhase.connecting ||
        snapshotPhase == ClientConnectionPhase.connected ||
        snapshotPhase == ClientConnectionPhase.disconnecting;

    return snapshotSuggestsActiveSession;
  }

  ClientConnectionPhase? _phaseFromName(String name) {
    for (final phase in ClientConnectionPhase.values) {
      if (phase.name == name) return phase;
    }
    return null;
  }

  String _buildRecoveryMessage(String? profileId) {
    if (profileId == null || profileId.trim().isEmpty) {
      return 'Recovered from an interrupted runtime session. The app restored a safe state and you can retry from Profiles.';
    }
    return 'Recovered from an interrupted runtime session for $profileId. The app restored a safe state and you can retry from Profiles.';
  }

  void _notifyIfActive() {
    if (_disposed) return;
    notifyListeners();
  }

  void _recordEvent({
    required String title,
    required String message,
    required ClientConnectionPhase phase,
    String? profileId,
    ClientControllerEventLevel level = ClientControllerEventLevel.info,
    ClientControllerEventKind kind = ClientControllerEventKind.lifecycle,
    String? operationId,
    int? step,
  }) {
    final event = ClientControllerEvent(
      id: 'event-${++_eventCounter}',
      timestamp: DateTime.now(),
      title: title,
      message: message,
      phase: phase,
      level: level,
      kind: kind,
      profileId: profileId,
      operationId: operationId,
      step: step,
    );
    _events.insert(0, event);
    if (_events.length > _maxEvents) {
      _events.removeRange(_maxEvents, _events.length);
    }
  }
}

class _PersistedRuntimeSnapshot {
  const _PersistedRuntimeSnapshot({
    required this.statusPhase,
    required this.statusMessage,
    required this.activeProfileId,
    required this.statusUpdatedAt,
    required this.sessionPhase,
    required this.sessionIsRunning,
    required this.sessionStopRequested,
    required this.sessionStopRequestedAt,
    required this.sessionPid,
    required this.sessionActiveConfigPath,
    required this.sessionConfigProvenance,
    required this.sessionExpectedLocalSocksPort,
    required this.sessionLaunchPlanSummary,
    required this.sessionLastExitCode,
    required this.sessionLastError,
    required this.sessionUpdatedAt,
  });

  final String statusPhase;
  final String statusMessage;
  final String? activeProfileId;
  final DateTime statusUpdatedAt;
  final String sessionPhase;
  final bool sessionIsRunning;
  final bool sessionStopRequested;
  final DateTime? sessionStopRequestedAt;
  final int? sessionPid;
  final String? sessionActiveConfigPath;
  final String? sessionConfigProvenance;
  final int? sessionExpectedLocalSocksPort;
  final String? sessionLaunchPlanSummary;
  final int? sessionLastExitCode;
  final String? sessionLastError;
  final DateTime sessionUpdatedAt;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'statusPhase': statusPhase,
      'statusMessage': statusMessage,
      'activeProfileId': activeProfileId,
      'statusUpdatedAt': statusUpdatedAt.toIso8601String(),
      'sessionPhase': sessionPhase,
      'sessionIsRunning': sessionIsRunning,
      'sessionStopRequested': sessionStopRequested,
      'sessionStopRequestedAt': sessionStopRequestedAt?.toIso8601String(),
      'sessionPid': sessionPid,
      'sessionActiveConfigPath': sessionActiveConfigPath,
      'sessionConfigProvenance': sessionConfigProvenance,
      'sessionExpectedLocalSocksPort': sessionExpectedLocalSocksPort,
      'sessionLaunchPlanSummary': sessionLaunchPlanSummary,
      'sessionLastExitCode': sessionLastExitCode,
      'sessionLastError': sessionLastError,
      'sessionUpdatedAt': sessionUpdatedAt.toIso8601String(),
    };
  }

  static _PersistedRuntimeSnapshot? fromJson(Object? value) {
    if (value is! Map) return null;
    final statusPhase = value['statusPhase'];
    final statusMessage = value['statusMessage'];
    final activeProfileId = value['activeProfileId'];
    final statusUpdatedAt = value['statusUpdatedAt'];
    final sessionPhase = value['sessionPhase'];
    final sessionIsRunning = value['sessionIsRunning'];
    final sessionStopRequested = value['sessionStopRequested'];
    final sessionStopRequestedAt = value['sessionStopRequestedAt'];
    final sessionPid = value['sessionPid'];
    final sessionActiveConfigPath = value['sessionActiveConfigPath'];
    final sessionConfigProvenance = value['sessionConfigProvenance'];
    final sessionExpectedLocalSocksPort =
        value['sessionExpectedLocalSocksPort'];
    final sessionLaunchPlanSummary = value['sessionLaunchPlanSummary'];
    final sessionLastExitCode = value['sessionLastExitCode'];
    final sessionLastError = value['sessionLastError'];
    final sessionUpdatedAt = value['sessionUpdatedAt'];

    if (statusPhase is! String ||
        statusMessage is! String ||
        statusUpdatedAt is! String ||
        sessionIsRunning is! bool ||
        sessionUpdatedAt is! String) {
      return null;
    }

    final parsedStatusUpdatedAt = DateTime.tryParse(statusUpdatedAt);
    final parsedSessionUpdatedAt = DateTime.tryParse(sessionUpdatedAt);
    if (parsedStatusUpdatedAt == null || parsedSessionUpdatedAt == null) {
      return null;
    }

    return _PersistedRuntimeSnapshot(
      statusPhase: statusPhase,
      statusMessage: statusMessage,
      activeProfileId: activeProfileId is String ? activeProfileId : null,
      statusUpdatedAt: parsedStatusUpdatedAt,
      sessionPhase: sessionPhase is String ? sessionPhase : 'stopped',
      sessionIsRunning: sessionIsRunning,
      sessionStopRequested:
          sessionStopRequested is bool ? sessionStopRequested : false,
      sessionStopRequestedAt: sessionStopRequestedAt is String
          ? DateTime.tryParse(sessionStopRequestedAt)
          : null,
      sessionPid: sessionPid is int ? sessionPid : null,
      sessionActiveConfigPath:
          sessionActiveConfigPath is String ? sessionActiveConfigPath : null,
      sessionConfigProvenance:
          sessionConfigProvenance is String ? sessionConfigProvenance : null,
      sessionExpectedLocalSocksPort: sessionExpectedLocalSocksPort is int
          ? sessionExpectedLocalSocksPort
          : null,
      sessionLaunchPlanSummary:
          sessionLaunchPlanSummary is String ? sessionLaunchPlanSummary : null,
      sessionLastExitCode:
          sessionLastExitCode is int ? sessionLastExitCode : null,
      sessionLastError: sessionLastError is String ? sessionLastError : null,
      sessionUpdatedAt: parsedSessionUpdatedAt,
    );
  }
}
