import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/controller/application/adapter_backed_client_controller.dart';
import 'package:trojan_pro_client/features/controller/application/shell_controller_adapter.dart';
import 'package:trojan_pro_client/features/controller/domain/client_connection_status.dart';
import 'package:trojan_pro_client/features/controller/domain/controller_command.dart';
import 'package:trojan_pro_client/features/controller/domain/controller_command_result.dart';
import 'package:trojan_pro_client/features/controller/domain/controller_runtime_config.dart';
import 'package:trojan_pro_client/features/controller/domain/controller_runtime_health.dart';
import 'package:trojan_pro_client/features/controller/domain/controller_runtime_session.dart';
import 'package:trojan_pro_client/features/controller/domain/controller_telemetry_snapshot.dart';
import 'package:trojan_pro_client/features/profiles/application/profile_secrets_service.dart';
import 'package:trojan_pro_client/features/profiles/domain/client_profile.dart';
import 'package:trojan_pro_client/platform/secure_storage/memory_secure_storage.dart';
import 'package:trojan_pro_client/platform/services/client_filesystem_layout.dart';
import 'package:trojan_pro_client/platform/services/memory_local_state_store.dart';

final _fixedTime = DateTime.parse('2026-03-13T00:00:00.000Z');

class _ControllableShellControllerAdapter implements ShellControllerAdapter {
  _ControllableShellControllerAdapter({
    required this.runtimeConfig,
    required this.commandAccepted,
    required this.commandSummary,
    this.commandError,
    this.commandDetails = const <String, Object?>{},
    required ControllerRuntimeSession initialSession,
  }) : _session = initialSession;

  @override
  final ControllerRuntimeConfig runtimeConfig;
  bool commandAccepted;
  String commandSummary;
  String? commandError;
  Map<String, Object?> commandDetails;
  ControllerCommand? lastCommand;

  ControllerRuntimeSession _session;

  @override
  ControllerTelemetrySnapshot get telemetry => ControllerTelemetrySnapshot(
        backendKind: 'controllable-test-adapter',
        backendVersion: 'test',
        capabilities: const <String>['connect', 'disconnect', 'healthCheck'],
        lastUpdatedAt: _fixedTime,
      );

  @override
  ControllerRuntimeSession get session => _session;

  void setSession(ControllerRuntimeSession session) {
    _session = session;
  }

  @override
  Future<ControllerRuntimeHealth> checkHealth() async {
    return ControllerRuntimeHealth(
      level: ControllerRuntimeHealthLevel.healthy,
      summary: 'test adapter healthy',
      updatedAt: _fixedTime,
    );
  }

  @override
  Future<ControllerCommandResult> execute(ControllerCommand command) async {
    lastCommand = command;
    return ControllerCommandResult(
      commandId: command.id,
      accepted: commandAccepted,
      completedAt: _fixedTime,
      summary: commandSummary,
      error: commandError,
      details: commandDetails,
    );
  }
}

ClientProfile _demoProfile() {
  return ClientProfile(
    id: 'profile-demo',
    name: 'demo-profile',
    serverHost: 'example.com',
    serverPort: 443,
    sni: 'example.com',
    localSocksPort: 1080,
    verifyTls: true,
    updatedAt: _fixedTime,
  );
}

ControllerRuntimeSession _session({
  required bool isRunning,
  int? pid,
  int? lastExitCode,
  String? lastError,
  ControllerRuntimePhase? phase,
  bool stopRequested = false,
  DateTime? stopRequestedAt,
}) {
  return ControllerRuntimeSession(
    isRunning: isRunning,
    updatedAt: DateTime.now(),
    phase: phase ??
        (isRunning
            ? ControllerRuntimePhase.sessionReady
            : ControllerRuntimePhase.stopped),
    stopRequested: stopRequested,
    stopRequestedAt: stopRequestedAt,
    pid: pid,
    lastExitCode: lastExitCode,
    lastError: lastError,
  );
}

/// 条件轮询，避免固定延迟导致的 flaky test
Future<void> _waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 3),
  Duration step = const Duration(milliseconds: 25),
  required String description,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (condition()) return;
    await Future<void>.delayed(step);
  }
  fail('Timed out waiting for: $description');
}

void main() {
  test('collectDiagnostics forwards bundle kind through adapter boundary',
      () async {
    final adapter = _ControllableShellControllerAdapter(
      runtimeConfig: const ControllerRuntimeConfig(
        mode: 'external-runtime-boundary',
        endpointHint: 'local-controller://test',
        enableVerboseTelemetry: true,
      ),
      commandAccepted: true,
      commandSummary: 'Collect diagnostics accepted.',
      commandDetails: const <String, Object?>{},
      initialSession: _session(isRunning: false),
    );
    final controller = AdapterBackedClientController(
      adapter: adapter,
      profileSecrets: ProfileSecretsService(secureStorage: MemorySecureStorage()),
      sessionPollInterval: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);

    final result = await controller.collectDiagnostics(
      bundleKind: 'support-bundle',
    );

    expect(result.accepted, isTrue);
    expect(adapter.lastCommand, isNotNull);
    expect(
      adapter.lastCommand!.kind,
      ControllerCommandKind.collectDiagnostics,
    );
    expect(
      adapter.lastCommand!.arguments['bundleKind'],
      'support-bundle',
    );
  });

  test('prepareExport forwards bundle kind through adapter boundary',
      () async {
    final adapter = _ControllableShellControllerAdapter(
      runtimeConfig: const ControllerRuntimeConfig(
        mode: 'external-runtime-boundary',
        endpointHint: 'local-controller://test',
        enableVerboseTelemetry: true,
      ),
      commandAccepted: true,
      commandSummary: 'Prepare export accepted.',
      commandDetails: const <String, Object?>{},
      initialSession: _session(isRunning: false),
    );
    final controller = AdapterBackedClientController(
      adapter: adapter,
      profileSecrets: ProfileSecretsService(secureStorage: MemorySecureStorage()),
      sessionPollInterval: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);

    final result = await controller.prepareExport(
      bundleKind: 'runtime-proof-artifact',
    );

    expect(result.accepted, isTrue);
    expect(adapter.lastCommand, isNotNull);
    expect(
      adapter.lastCommand!.kind,
      ControllerCommandKind.prepareExport,
    );
    expect(
      adapter.lastCommand!.arguments['bundleKind'],
      'runtime-proof-artifact',
    );
  });

  test(
      'promotes connecting status to connected when runtime session starts running',
      () async {
    final adapter = _ControllableShellControllerAdapter(
      runtimeConfig: const ControllerRuntimeConfig(
        mode: 'external-runtime-boundary',
        endpointHint: 'local-controller://test',
        enableVerboseTelemetry: true,
      ),
      commandAccepted: true,
      commandSummary: 'Launch requested.',
      commandDetails: const <String, Object?>{},
      initialSession: _session(isRunning: false),
    );
    final secrets = ProfileSecretsService(secureStorage: MemorySecureStorage());
    await secrets.saveTrojanPassword(
        profileId: 'profile-demo', password: 'secret');

    final controller = AdapterBackedClientController(
      adapter: adapter,
      profileSecrets: secrets,
      sessionPollInterval: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);

    await controller.connect(_demoProfile());
    expect(controller.status.phase, ClientConnectionPhase.connecting);

    adapter.setSession(_session(isRunning: true, pid: 4321));
    await _waitFor(
      () => controller.status.phase == ClientConnectionPhase.connected,
      description: 'status transitions to connected',
    );

    expect(controller.status.phase, ClientConnectionPhase.connected);
    expect(controller.status.message, contains('Runtime session is ready'));
    expect(
      controller.recentEvents.first.title,
      anyOf(equals('Runtime session ready'), equals('Connect requested')),
    );
  });

  test('keeps connecting status while runtime is alive but not session-ready',
      () async {
    final adapter = _ControllableShellControllerAdapter(
      runtimeConfig: const ControllerRuntimeConfig(
        mode: 'external-runtime-boundary',
        endpointHint: 'local-controller://test',
        enableVerboseTelemetry: true,
      ),
      commandAccepted: true,
      commandSummary: 'Launch requested.',
      commandDetails: const <String, Object?>{},
      initialSession: _session(isRunning: false),
    );
    final secrets = ProfileSecretsService(secureStorage: MemorySecureStorage());
    await secrets.saveTrojanPassword(
        profileId: 'profile-demo', password: 'secret');

    final controller = AdapterBackedClientController(
      adapter: adapter,
      profileSecrets: secrets,
      sessionPollInterval: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);

    await controller.connect(_demoProfile());
    expect(controller.status.phase, ClientConnectionPhase.connecting);

    adapter.setSession(
      _session(
        isRunning: true,
        pid: 4321,
        phase: ControllerRuntimePhase.alive,
      ),
    );
    await _waitFor(
      () => controller.status.message.contains('Waiting for session-ready'),
      description: 'connecting status reflects alive-but-not-ready runtime',
    );

    expect(controller.status.phase, ClientConnectionPhase.connecting);
    expect(controller.status.message, contains('Waiting for session-ready'));
  });

  test(
      'moves connected status to error when runtime session exits with non-zero code',
      () async {
    final adapter = _ControllableShellControllerAdapter(
      runtimeConfig: const ControllerRuntimeConfig(
        mode: 'external-runtime-boundary',
        endpointHint: 'local-controller://test',
        enableVerboseTelemetry: true,
      ),
      commandAccepted: true,
      commandSummary: 'Launch requested.',
      commandDetails: const <String, Object?>{},
      initialSession: _session(isRunning: false),
    );
    final secrets = ProfileSecretsService(secureStorage: MemorySecureStorage());
    await secrets.saveTrojanPassword(
        profileId: 'profile-demo', password: 'secret');

    final controller = AdapterBackedClientController(
      adapter: adapter,
      profileSecrets: secrets,
      sessionPollInterval: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);

    await controller.connect(_demoProfile());
    adapter.setSession(_session(isRunning: true, pid: 4321));
    await _waitFor(
      () => controller.status.phase == ClientConnectionPhase.connected,
      description: 'status transitions to connected',
    );

    adapter.setSession(_session(isRunning: false, lastExitCode: 7));
    await _waitFor(
      () => controller.status.phase == ClientConnectionPhase.error,
      description: 'status transitions to error after non-zero exit',
    );

    expect(controller.status.phase, ClientConnectionPhase.error);
    expect(controller.status.message, contains('code 7'));
    expect(controller.status.errorCode, 'RUNTIME_SESSION_EXIT_NONZERO');
    expect(controller.status.failureFamilyHint, 'connect');
  });

  test('moves connected status to disconnected when runtime exits cleanly',
      () async {
    final adapter = _ControllableShellControllerAdapter(
      runtimeConfig: const ControllerRuntimeConfig(
        mode: 'external-runtime-boundary',
        endpointHint: 'local-controller://test',
        enableVerboseTelemetry: true,
      ),
      commandAccepted: true,
      commandSummary: 'Launch requested.',
      commandDetails: const <String, Object?>{},
      initialSession: _session(isRunning: false),
    );
    final secrets = ProfileSecretsService(secureStorage: MemorySecureStorage());
    await secrets.saveTrojanPassword(
        profileId: 'profile-demo', password: 'secret');

    final controller = AdapterBackedClientController(
      adapter: adapter,
      profileSecrets: secrets,
      sessionPollInterval: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);

    await controller.connect(_demoProfile());
    adapter.setSession(_session(isRunning: true, pid: 4321));
    await _waitFor(
      () => controller.status.phase == ClientConnectionPhase.connected,
      description: 'status transitions to connected',
    );

    adapter.setSession(_session(isRunning: false, lastExitCode: 0));
    await _waitFor(
      () => controller.status.phase == ClientConnectionPhase.disconnected,
      description: 'status transitions to disconnected after clean exit',
    );

    expect(controller.status.phase, ClientConnectionPhase.disconnected);
    expect(controller.status.message, contains('cleanly'));
  });

  test('enters disconnecting phase before disconnect completes', () async {
    final adapter = _ControllableShellControllerAdapter(
      runtimeConfig: const ControllerRuntimeConfig(
        mode: 'external-runtime-boundary',
        endpointHint: 'local-controller://test',
        enableVerboseTelemetry: true,
      ),
      commandAccepted: true,
      commandSummary: 'Disconnect requested.',
      commandDetails: const <String, Object?>{},
      initialSession: _session(isRunning: true, pid: 9001),
    );
    final secrets = ProfileSecretsService(secureStorage: MemorySecureStorage());
    await secrets.saveTrojanPassword(
      profileId: 'profile-demo',
      password: 'secret',
    );

    final controller = AdapterBackedClientController(
      adapter: adapter,
      profileSecrets: secrets,
      sessionPollInterval: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);

    await controller.connect(_demoProfile());
    adapter.setSession(_session(isRunning: true, pid: 4321));
    await _waitFor(
      () => controller.status.phase == ClientConnectionPhase.connected,
      description: 'status transitions to connected before disconnect',
    );

    final disconnectFuture = controller.disconnect();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(controller.status.phase, ClientConnectionPhase.disconnecting);
    expect(controller.status.activeProfileId, 'profile-demo');

    await disconnectFuture;
    adapter.setSession(
      _session(
        isRunning: true,
        pid: 4321,
        phase: ControllerRuntimePhase.alive,
        stopRequested: true,
        stopRequestedAt: _fixedTime,
      ),
    );
    await _waitFor(
      () => controller.status.message.contains('Waiting for the runtime process to exit cleanly'),
      description: 'disconnecting status reflects stop-requested runtime',
    );

    expect(
      controller.status.phase,
      anyOf(
        equals(ClientConnectionPhase.disconnecting),
        equals(ClientConnectionPhase.disconnected),
      ),
    );
    expect(
      controller.status.message,
      contains('Waiting for the runtime process to exit cleanly'),
    );
  });

  test('allows retry after missing password once password is saved', () async {
    final adapter = _ControllableShellControllerAdapter(
      runtimeConfig: const ControllerRuntimeConfig(
        mode: 'external-runtime-boundary',
        endpointHint: 'local-controller://test',
        enableVerboseTelemetry: true,
      ),
      commandAccepted: true,
      commandSummary: 'Launch requested.',
      commandDetails: const <String, Object?>{},
      initialSession: _session(isRunning: false),
    );
    final secrets = ProfileSecretsService(secureStorage: MemorySecureStorage());

    final controller = AdapterBackedClientController(
      adapter: adapter,
      profileSecrets: secrets,
      sessionPollInterval: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);

    final firstResult = await controller.connect(_demoProfile());
    expect(firstResult.accepted, isFalse);
    expect(controller.status.phase, ClientConnectionPhase.error);
    expect(controller.status.message, 'MISSING_TROJAN_PASSWORD');
    expect(controller.status.errorCode, 'MISSING_TROJAN_PASSWORD');
    expect(controller.status.failureFamilyHint, 'user_input');

    await secrets.saveTrojanPassword(
      profileId: 'profile-demo',
      password: 'secret',
    );

    final retryResult = await controller.connect(_demoProfile());
    expect(retryResult.accepted, isTrue);
    expect(controller.status.phase, ClientConnectionPhase.connecting);

    adapter.setSession(_session(isRunning: true, pid: 4321));
    await _waitFor(
      () => controller.status.phase == ClientConnectionPhase.connected,
      description: 'status transitions to connected after retry succeeds',
    );

    expect(controller.status.phase, ClientConnectionPhase.connected);
    expect(controller.status.activeProfileId, 'profile-demo');
    expect(controller.status.errorCode, isNull);
    expect(controller.status.failureFamilyHint, isNull);
  });

  test('persists last runtime failure summary to local state store', () async {
    final adapter = _ControllableShellControllerAdapter(
      runtimeConfig: const ControllerRuntimeConfig(
        mode: 'external-runtime-boundary',
        endpointHint: 'local-controller://test',
        enableVerboseTelemetry: true,
      ),
      commandAccepted: false,
      commandSummary: 'Launch request rejected by runtime boundary.',
      commandError: 'config invalid for runtime launch',
      commandDetails: const <String, Object?>{},
      initialSession: _session(isRunning: false),
    );
    final localState = MemoryLocalStateStore();
    final secrets = ProfileSecretsService(secureStorage: MemorySecureStorage());
    await secrets.saveTrojanPassword(
      profileId: 'profile-demo',
      password: 'secret',
    );

    final controller = AdapterBackedClientController(
      adapter: adapter,
      profileSecrets: secrets,
      localStateStore: localState,
      sessionPollInterval: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);

    final result = await controller.connect(_demoProfile());
    expect(result.accepted, isFalse);
    expect(controller.lastRuntimeFailure, isNotNull);
    expect(controller.lastRuntimeFailure!.phase, 'launch');
    expect(controller.status.failureFamilyHint, 'config');

    final persistedRaw =
        await localState.read('controller.lastRuntimeFailureSummary');
    expect(persistedRaw, isNotNull);
    final persisted = jsonDecode(persistedRaw!) as Map<String, Object?>;
    expect(persisted['phase'], 'launch');
    expect(persisted['family'], 'config');
    expect(persisted['profileId'], 'profile-demo');
  });

  test('classifies runtime exit failure as connect family', () async {
    final localState = MemoryLocalStateStore();
    final adapter = _ControllableShellControllerAdapter(
      runtimeConfig: const ControllerRuntimeConfig(
        mode: 'external-runtime-boundary',
        endpointHint: 'local-controller://test',
        enableVerboseTelemetry: true,
      ),
      commandAccepted: true,
      commandSummary: 'Launch requested.',
      commandDetails: const <String, Object?>{},
      initialSession: _session(isRunning: false),
    );
    final secrets = ProfileSecretsService(secureStorage: MemorySecureStorage());
    await secrets.saveTrojanPassword(
      profileId: 'profile-demo',
      password: 'secret',
    );

    final controller = AdapterBackedClientController(
      adapter: adapter,
      profileSecrets: secrets,
      localStateStore: localState,
      sessionPollInterval: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);

    await controller.connect(_demoProfile());
    adapter.setSession(_session(isRunning: true, pid: 4321));
    await _waitFor(
      () => controller.status.phase == ClientConnectionPhase.connected,
      description: 'status transitions to connected before exit family check',
    );

    adapter.setSession(_session(isRunning: false, lastExitCode: 7));
    await _waitFor(
      () => controller.status.phase == ClientConnectionPhase.error,
      description: 'status transitions to error after runtime exit',
    );

    expect(controller.status.errorCode, 'RUNTIME_SESSION_EXIT_NONZERO');
    expect(controller.status.failureFamilyHint, 'connect');

    final persistedRaw =
        await localState.read('controller.lastRuntimeFailureSummary');
    expect(persistedRaw, isNotNull);
    final persisted = jsonDecode(persistedRaw!) as Map<String, Object?>;
    expect(persisted['phase'], 'runtime');
    expect(persisted['family'], 'connect');
  });

  test('reaches disconnected state after disconnecting session fully stops',
      () async {
    final adapter = _ControllableShellControllerAdapter(
      runtimeConfig: const ControllerRuntimeConfig(
        mode: 'external-runtime-boundary',
        endpointHint: 'local-controller://test',
        enableVerboseTelemetry: true,
      ),
      commandAccepted: true,
      commandSummary: 'Disconnect requested.',
      commandDetails: const <String, Object?>{},
      initialSession: _session(isRunning: true, pid: 9001),
    );
    final secrets = ProfileSecretsService(secureStorage: MemorySecureStorage());
    await secrets.saveTrojanPassword(
      profileId: 'profile-demo',
      password: 'secret',
    );

    final controller = AdapterBackedClientController(
      adapter: adapter,
      profileSecrets: secrets,
      sessionPollInterval: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);

    await controller.connect(_demoProfile());
    adapter.setSession(_session(isRunning: true, pid: 4321));
    await _waitFor(
      () => controller.status.phase == ClientConnectionPhase.connected,
      description: 'status transitions to connected before full disconnect',
    );

    await controller.disconnect();
    expect(controller.status.phase, ClientConnectionPhase.disconnecting);

    adapter.setSession(_session(isRunning: false, lastExitCode: 0));
    await _waitFor(
      () => controller.status.phase == ClientConnectionPhase.disconnected,
      description: 'status transitions to disconnected after session stops',
    );

    expect(controller.status.phase, ClientConnectionPhase.disconnected);
    expect(controller.status.activeProfileId, isNull);
  });

  test('restores stale running snapshot into safe recovery state on launch',
      () async {
    final localState = MemoryLocalStateStore();
    await localState.write(
      'controller.runtimeSessionSnapshot',
      jsonEncode(<String, Object?>{
        'statusPhase': 'connected',
        'statusMessage': 'Runtime session is active.',
        'activeProfileId': 'profile-demo',
        'statusUpdatedAt': _fixedTime.toIso8601String(),
        'sessionIsRunning': true,
        'sessionPid': 12345,
        'sessionActiveConfigPath': null,
        'sessionLastExitCode': null,
        'sessionLastError': null,
        'sessionUpdatedAt': _fixedTime.toIso8601String(),
      }),
    );

    final adapter = _ControllableShellControllerAdapter(
      runtimeConfig: const ControllerRuntimeConfig(
        mode: 'external-runtime-boundary',
        endpointHint: 'local-controller://test',
        enableVerboseTelemetry: true,
      ),
      commandAccepted: true,
      commandSummary: 'Launch requested.',
      commandDetails: const <String, Object?>{},
      initialSession: _session(isRunning: false),
    );
    final secrets = ProfileSecretsService(secureStorage: MemorySecureStorage());

    final controller = AdapterBackedClientController(
      adapter: adapter,
      profileSecrets: secrets,
      localStateStore: localState,
      sessionPollInterval: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);

    await controller.restorePersistedState();

    expect(controller.status.phase, ClientConnectionPhase.error);
    expect(
      controller.status.message,
      contains('Recovered from an interrupted runtime session'),
    );
    expect(controller.status.errorCode, 'RUNTIME_RECOVERY_INTERRUPTED_SESSION');
    expect(controller.status.failureFamilyHint, 'launch');
    expect(controller.status.activeProfileId, 'profile-demo');
    expect(controller.lastRuntimeFailure, isNotNull);
    expect(controller.lastRuntimeFailure!.phase, 'recovery');
  });

  test('cleans stale runtime config artifact during recovery pass', () async {
    final tempDir =
        await Directory.systemTemp.createTemp('adapter-recovery-cleanup-test');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final stateDir = '${tempDir.path}${Platform.pathSeparator}state';
    final runtimeDir = '$stateDir${Platform.pathSeparator}runtime';
    final staleConfigPath =
        '$runtimeDir${Platform.pathSeparator}runtime-profile-profile-demo.json';
    await Directory(runtimeDir).create(recursive: true);
    await File(staleConfigPath).writeAsString('{"stale":true}', flush: true);

    final localState = MemoryLocalStateStore();
    await localState.write(
      'controller.runtimeSessionSnapshot',
      jsonEncode(<String, Object?>{
        'statusPhase': 'connected',
        'statusMessage': 'Runtime session is active.',
        'activeProfileId': 'profile-demo',
        'statusUpdatedAt': _fixedTime.toIso8601String(),
        'sessionIsRunning': true,
        'sessionPid': 23456,
        'sessionActiveConfigPath': staleConfigPath,
        'sessionLastExitCode': null,
        'sessionLastError': null,
        'sessionUpdatedAt': _fixedTime.toIso8601String(),
      }),
    );

    final adapter = _ControllableShellControllerAdapter(
      runtimeConfig: const ControllerRuntimeConfig(
        mode: 'external-runtime-boundary',
        endpointHint: 'local-controller://test',
        enableVerboseTelemetry: true,
      ),
      commandAccepted: true,
      commandSummary: 'Launch requested.',
      commandDetails: const <String, Object?>{},
      initialSession: _session(isRunning: false),
    );
    final secrets = ProfileSecretsService(secureStorage: MemorySecureStorage());

    final controller = AdapterBackedClientController(
      adapter: adapter,
      profileSecrets: secrets,
      localStateStore: localState,
      filesystemLayout: ClientFilesystemLayout(
        stateDirectoryPath: stateDir,
        diagnosticsDirectoryPath:
            '${tempDir.path}${Platform.pathSeparator}diagnostics',
      ),
      sessionPollInterval: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);

    await controller.restorePersistedState();

    expect(await File(staleConfigPath).exists(), isFalse);
  });

  test('clears persisted failure after retry succeeds and runtime reconnects',
      () async {
    final localState = MemoryLocalStateStore();
    final adapter = _ControllableShellControllerAdapter(
      runtimeConfig: const ControllerRuntimeConfig(
        mode: 'external-runtime-boundary',
        endpointHint: 'local-controller://test',
        enableVerboseTelemetry: true,
      ),
      commandAccepted: false,
      commandSummary: 'Launch request rejected by runtime boundary.',
      commandError: 'config invalid for runtime launch',
      commandDetails: const <String, Object?>{},
      initialSession: _session(isRunning: false),
    );
    final secrets = ProfileSecretsService(secureStorage: MemorySecureStorage());
    await secrets.saveTrojanPassword(
      profileId: 'profile-demo',
      password: 'secret',
    );

    final controller = AdapterBackedClientController(
      adapter: adapter,
      profileSecrets: secrets,
      localStateStore: localState,
      sessionPollInterval: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);

    final failed = await controller.connect(_demoProfile());
    expect(failed.accepted, isFalse);
    expect(controller.lastRuntimeFailure, isNotNull);
    expect(
      await localState.read('controller.lastRuntimeFailureSummary'),
      isNotNull,
    );

    adapter.commandAccepted = true;
    adapter.commandSummary = 'Launch requested.';
    adapter.commandError = null;
    adapter.commandDetails = const <String, Object?>{};

    final retry = await controller.connect(_demoProfile());
    expect(retry.accepted, isTrue);

    adapter.setSession(_session(isRunning: true, pid: 4321));
    await _waitFor(
      () => controller.status.phase == ClientConnectionPhase.connected,
      description: 'retry reconnects runtime session',
    );
    await _waitFor(
      () => controller.lastRuntimeFailure == null,
      description: 'persisted failure clears after successful retry',
    );

    expect(
      await localState.read('controller.lastRuntimeFailureSummary'),
      isNull,
    );
  });

  test('disconnect completion does not create a new runtime failure summary',
      () async {
    final localState = MemoryLocalStateStore();
    final adapter = _ControllableShellControllerAdapter(
      runtimeConfig: const ControllerRuntimeConfig(
        mode: 'external-runtime-boundary',
        endpointHint: 'local-controller://test',
        enableVerboseTelemetry: true,
      ),
      commandAccepted: true,
      commandSummary: 'Disconnect requested.',
      commandDetails: const <String, Object?>{},
      initialSession: _session(isRunning: true, pid: 9001),
    );
    final secrets = ProfileSecretsService(secureStorage: MemorySecureStorage());
    await secrets.saveTrojanPassword(
      profileId: 'profile-demo',
      password: 'secret',
    );

    final controller = AdapterBackedClientController(
      adapter: adapter,
      profileSecrets: secrets,
      localStateStore: localState,
      sessionPollInterval: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);

    await controller.connect(_demoProfile());
    adapter.setSession(_session(isRunning: true, pid: 4321));
    await _waitFor(
      () => controller.status.phase == ClientConnectionPhase.connected,
      description:
          'status transitions to connected before disconnect regression check',
    );

    await controller.disconnect();
    adapter.setSession(
      _session(isRunning: false, lastExitCode: 137, lastError: 'terminated'),
    );
    await _waitFor(
      () => controller.status.phase == ClientConnectionPhase.disconnected,
      description: 'disconnect completes into disconnected state',
    );

    expect(controller.lastRuntimeFailure, isNull);
    expect(
      await localState.read('controller.lastRuntimeFailureSummary'),
      isNull,
    );
    expect(controller.status.message, contains('disconnect request'));
    expect(controller.status.errorCode, isNull);
    expect(controller.status.failureFamilyHint, isNull);
  });

  test('does not recover when persisted snapshot is already disconnected',
      () async {
    final localState = MemoryLocalStateStore();
    await localState.write(
      'controller.runtimeSessionSnapshot',
      jsonEncode(<String, Object?>{
        'statusPhase': 'disconnected',
        'statusMessage': 'Runtime session ended cleanly.',
        'activeProfileId': null,
        'statusUpdatedAt': _fixedTime.toIso8601String(),
        'sessionIsRunning': false,
        'sessionPid': null,
        'sessionActiveConfigPath': null,
        'sessionLastExitCode': 0,
        'sessionLastError': null,
        'sessionUpdatedAt': _fixedTime.toIso8601String(),
      }),
    );

    final adapter = _ControllableShellControllerAdapter(
      runtimeConfig: const ControllerRuntimeConfig(
        mode: 'external-runtime-boundary',
        endpointHint: 'local-controller://test',
        enableVerboseTelemetry: true,
      ),
      commandAccepted: true,
      commandSummary: 'Launch requested.',
      commandDetails: const <String, Object?>{},
      initialSession: _session(isRunning: false),
    );
    final secrets = ProfileSecretsService(secureStorage: MemorySecureStorage());

    final controller = AdapterBackedClientController(
      adapter: adapter,
      profileSecrets: secrets,
      localStateStore: localState,
      sessionPollInterval: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);

    await controller.restorePersistedState();

    expect(controller.status.phase, ClientConnectionPhase.disconnected);
    expect(controller.lastRuntimeFailure, isNull);
  });
}
