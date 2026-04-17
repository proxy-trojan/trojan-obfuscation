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
import 'package:trojan_pro_client/features/routing/testing/application/routing_probe_runner.dart';
import 'package:trojan_pro_client/features/routing/testing/domain/routing_probe_models.dart';
import 'package:trojan_pro_client/features/routing/testing/platform/routing_probe_adapter.dart';
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

class _ConfigurableRoutingProbeAdapter implements RoutingProbeAdapter {
  _ConfigurableRoutingProbeAdapter({this.shouldFail = false});

  bool shouldFail;

  @override
  RoutingProbePlatform get platform => RoutingProbePlatform.linux;

  @override
  Future<RoutingProbeObservation> executeProbe(
    RoutingProbeScenario scenario,
  ) async {
    return RoutingProbeObservation(
      platform: platform,
      scenarioId: scenario.id,
      observedResult: shouldFail
          ? RoutingProbeObservedResult.unknown
          : scenario.expected.expectedObservedResult,
      rawSummary: shouldFail
          ? 'forced mini smoke failure for ${scenario.id}'
          : 'mini smoke pass for ${scenario.id}',
      runtimePosture: shouldFail
          ? RoutingProbeRuntimePosture.fallbackStub
          : RoutingProbeRuntimePosture.runtimeTrue,
    );
  }
}

ClientProfile _demoProfile({String id = 'profile-demo'}) {
  return ClientProfile(
    id: id,
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
      profileSecrets:
          ProfileSecretsService(secureStorage: MemorySecureStorage()),
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

  test('prepareExport forwards bundle kind through adapter boundary', () async {
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
      profileSecrets:
          ProfileSecretsService(secureStorage: MemorySecureStorage()),
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

    expect(adapter.lastCommand, isNotNull);
    final routing = adapter.lastCommand!.arguments['routing'];
    expect(routing, isA<Map<String, Object?>>());
    final routingMap = routing! as Map<String, Object?>;
    expect(routingMap['mode'], 'rule');
    expect(routingMap['defaultAction'], 'proxy');
    expect(routingMap['globalAction'], 'proxy');

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

    adapter.setSession(
      _session(
        isRunning: false,
        lastExitCode: 137,
        lastError: 'killed',
      ),
    );
    await _waitFor(
      () => controller.status.phase == ClientConnectionPhase.error,
      description: 'status transitions to error after non-zero exit',
    );

    expect(controller.status.phase, ClientConnectionPhase.error);
    expect(controller.status.message, contains('Runtime session stopped'));
    expect(controller.status.errorCode, 'RUNTIME_SESSION_ERROR');
    expect(controller.status.failureFamilyHint, 'connect');
    expect(controller.lastRuntimeFailure, isNotNull);
  });

  test('keeps disconnected after clean exit code during disconnect flow',
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
      description: 'connected before disconnect check',
    );

    await controller.disconnect();
    adapter.setSession(_session(isRunning: false, lastExitCode: 0));
    await _waitFor(
      () => controller.status.phase == ClientConnectionPhase.disconnected,
      description: 'disconnect reaches disconnected on clean exit',
    );

    expect(controller.status.phase, ClientConnectionPhase.disconnected);
    expect(controller.status.errorCode, isNull);
    expect(controller.status.failureFamilyHint, isNull);
  });

  test('connect rejects when password is missing', () async {
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

    final controller = AdapterBackedClientController(
      adapter: adapter,
      profileSecrets:
          ProfileSecretsService(secureStorage: MemorySecureStorage()),
      sessionPollInterval: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);

    final result = await controller.connect(_demoProfile());

    expect(result.accepted, isFalse);
    expect(result.error, 'MISSING_TROJAN_PASSWORD');
    expect(controller.status.phase, ClientConnectionPhase.error);
    expect(controller.status.failureFamilyHint, 'user_input');
  });

  test('connect emits routing failure hint on launch rejection', () async {
    final adapter = _ControllableShellControllerAdapter(
      runtimeConfig: const ControllerRuntimeConfig(
        mode: 'external-runtime-boundary',
        endpointHint: 'local-controller://test',
        enableVerboseTelemetry: true,
      ),
      commandAccepted: false,
      commandSummary: 'Launch request rejected by adapter.',
      commandError: 'launch denied',
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
      sessionPollInterval: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);

    final result = await controller.connect(_demoProfile());

    expect(result.accepted, isFalse);
    expect(controller.status.phase, ClientConnectionPhase.error);
    expect(controller.status.failureFamilyHint, 'launch');
  });

  test('does not retain stale failure hint after successful connect', () async {
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
      sessionPollInterval: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);

    await controller.connect(_demoProfile());
    adapter.setSession(_session(isRunning: true, pid: 4321));

    await _waitFor(
      () => controller.status.phase == ClientConnectionPhase.connected,
      description: 'connect reaches connected state',
    );

    expect(controller.status.failureFamilyHint, isNull);
    expect(controller.status.errorCode, isNull);
  });

  test('connect records latest routing probe evidence for diagnostics fallback',
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
      profileId: 'profile-demo',
      password: 'secret',
    );

    final controller = AdapterBackedClientController(
      adapter: adapter,
      profileSecrets: secrets,
      routingProbeRunner: RoutingProbeRunner(
        adapters: <RoutingProbeAdapter>[
          _ConfigurableRoutingProbeAdapter(shouldFail: false),
        ],
      ),
      sessionPollInterval: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);

    final result = await controller.connect(_demoProfile());

    expect(result.accepted, isTrue);
    expect(controller.latestRoutingProbeEvidence, isNotEmpty);
    expect(
      controller.latestRoutingProbeEvidence.first.runtimePosture,
      RoutingProbeRuntimePosture.runtimeTrue,
    );
    expect(
      controller.latestRoutingProbeEvidence.first.isRuntimeTrueDataplane,
      isTrue,
    );
  });

  test('disconnect keeps disconnected state despite stale runtime poll updates',
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

  test('connect apply should rollback and enter safe mode on smoke failure',
      () async {
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
    await secrets.saveTrojanPassword(profileId: 'profile-stable', password: 'ok');
    await secrets.saveTrojanPassword(profileId: 'profile-candidate', password: 'ok');

    final probeAdapter = _ConfigurableRoutingProbeAdapter(shouldFail: false);

    final controller = AdapterBackedClientController(
      adapter: adapter,
      profileSecrets: secrets,
      localStateStore: localState,
      routingProbeRunner: RoutingProbeRunner(
        adapters: <RoutingProbeAdapter>[probeAdapter],
      ),
      sessionPollInterval: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);

    final stableResult =
        await controller.connect(_demoProfile(id: 'profile-stable'));
    expect(stableResult.accepted, isTrue);

    probeAdapter.shouldFail = true;

    final candidateResult =
        await controller.connect(_demoProfile(id: 'profile-candidate'));

    expect(candidateResult.accepted, isFalse);
    expect(candidateResult.error, 'ROUTING_APPLY_ROLLED_BACK');
    expect(controller.status.phase, ClientConnectionPhase.error);
    expect(controller.status.safeModeActive, isTrue);
    expect(controller.status.rollbackReason, isNotEmpty);
    expect(controller.status.quarantineKey, isNull);
    expect(controller.status.activeProfileId, 'profile-candidate');
    expect(
      controller.recentEvents
          .any((event) => event.title == 'Routing rollback applied'),
      isTrue,
    );

    final persisted = await localState.read('controller.routingSafetyState');
    expect(persisted, isNotNull);
    final payload = jsonDecode(persisted!) as Map<String, Object?>;
    expect(payload['safeModeActive'], isTrue);
    expect(payload['rollbackReason'], isNotNull);
  });

  test('second rollback in window should quarantine candidate', () async {
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

    final probeAdapter = _ConfigurableRoutingProbeAdapter(shouldFail: false);
    final secrets = ProfileSecretsService(secureStorage: MemorySecureStorage());
    await secrets.saveTrojanPassword(profileId: 'profile-stable', password: 'ok');
    await secrets.saveTrojanPassword(profileId: 'profile-candidate', password: 'ok');

    final controller = AdapterBackedClientController(
      adapter: adapter,
      profileSecrets: secrets,
      localStateStore: localState,
      routingProbeRunner: RoutingProbeRunner(
        adapters: <RoutingProbeAdapter>[probeAdapter],
      ),
      sessionPollInterval: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);

    final stableResult =
        await controller.connect(_demoProfile(id: 'profile-stable'));
    expect(stableResult.accepted, isTrue);

    probeAdapter.shouldFail = true;

    final firstFailure = await controller.connect(_demoProfile(id: 'profile-candidate'));
    expect(firstFailure.accepted, isFalse);
    expect(firstFailure.error, 'ROUTING_APPLY_ROLLED_BACK');

    final secondFailure = await controller.connect(_demoProfile(id: 'profile-candidate'));
    expect(secondFailure.accepted, isFalse);
    expect(secondFailure.error, 'ROUTING_APPLY_ROLLED_BACK_QUARANTINED');
    expect(controller.status.safeModeActive, isTrue);
    expect(controller.status.quarantineKey, 'profile-candidate');

    final blockedAfterQuarantine =
        await controller.connect(_demoProfile(id: 'profile-candidate'));
    expect(blockedAfterQuarantine.accepted, isFalse);
    expect(blockedAfterQuarantine.error, 'ROUTING_QUARANTINED');
  });

  test('quarantined candidate should be blocked before connect command',
      () async {
    final localState = MemoryLocalStateStore();
    await localState.write(
      'controller.routingSafetyState',
      jsonEncode(<String, Object?>{
        'safeModeActive': true,
        'quarantineKey': 'profile-candidate',
        'rollbackReason': 'prior rollback',
        'lastKnownGoodProfileId': 'profile-stable',
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
    await secrets.saveTrojanPassword(profileId: 'profile-candidate', password: 'ok');

    final controller = AdapterBackedClientController(
      adapter: adapter,
      profileSecrets: secrets,
      localStateStore: localState,
      sessionPollInterval: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);

    await controller.restorePersistedState();

    final result = await controller.connect(_demoProfile(id: 'profile-candidate'));

    expect(result.accepted, isFalse);
    expect(result.error, 'ROUTING_QUARANTINED');
    expect(controller.status.safeModeActive, isTrue);
    expect(controller.status.quarantineKey, 'profile-candidate');
    expect(adapter.lastCommand, isNull);
  });

  test('connect emits analytics events for success and failures', () async {
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
    await secrets.saveTrojanPassword(profileId: 'profile-demo', password: 'secret');

    final controller = AdapterBackedClientController(
      adapter: adapter,
      profileSecrets: secrets,
      routingProbeRunner: RoutingProbeRunner(
        adapters: <RoutingProbeAdapter>[
          _ConfigurableRoutingProbeAdapter(shouldFail: false),
        ],
      ),
      sessionPollInterval: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);

    final connectResult = await controller.connect(_demoProfile());
    expect(connectResult.accepted, isTrue);

    adapter.setSession(_session(isRunning: true, pid: 4321));
    await _waitFor(
      () => controller.status.phase == ClientConnectionPhase.connected,
      description: 'connected state reached for analytics assertion',
    );

    expect(
      controller.latestUxEvents
          .any((event) => event.name == 'first_connect_attempted'),
      isTrue,
    );
    expect(
      controller.latestUxEvents
          .any((event) => event.name == 'runtime_session_ready_runtime_true'),
      isTrue,
    );

    adapter.setSession(
      _session(isRunning: false, lastExitCode: 9, lastError: 'boom'),
    );
    await _waitFor(
      () => controller.status.phase == ClientConnectionPhase.error,
      description: 'error state reached for analytics assertion',
    );

    expect(
      controller.latestUxEvents
          .any((event) => event.name == 'connect_failed_connect'),
      isTrue,
    );
    expect(
      controller.latestUxEvents.any((event) => event.name == 'recovery_suggested'),
      isTrue,
    );
  });
}
