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

class _ControllableShellControllerAdapter implements ShellControllerAdapter {
  _ControllableShellControllerAdapter({
    required this.runtimeConfig,
    required this.commandAccepted,
    required this.commandSummary,
    this.commandDetails = const <String, Object?>{},
    required ControllerRuntimeSession initialSession,
  }) : _session = initialSession;

  @override
  final ControllerRuntimeConfig runtimeConfig;
  final bool commandAccepted;
  final String commandSummary;
  final Map<String, Object?> commandDetails;

  ControllerRuntimeSession _session;

  @override
  ControllerTelemetrySnapshot get telemetry => ControllerTelemetrySnapshot(
        backendKind: 'controllable-test-adapter',
        backendVersion: 'test',
        capabilities: const <String>['connect', 'disconnect', 'healthCheck'],
        lastUpdatedAt: DateTime.now(),
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
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<ControllerCommandResult> execute(ControllerCommand command) async {
    return ControllerCommandResult(
      commandId: command.id,
      accepted: commandAccepted,
      completedAt: DateTime.now(),
      summary: commandSummary,
      error: null,
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
    updatedAt: DateTime.now(),
  );
}

ControllerRuntimeSession _session({
  required bool isRunning,
  int? pid,
  int? lastExitCode,
  String? lastError,
}) {
  return ControllerRuntimeSession(
    isRunning: isRunning,
    updatedAt: DateTime.now(),
    pid: pid,
    lastExitCode: lastExitCode,
    lastError: lastError,
  );
}

void main() {
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
    await Future<void>.delayed(const Duration(milliseconds: 90));

    expect(controller.status.phase, ClientConnectionPhase.connected);
    expect(controller.status.message, contains('Runtime session is active'));
    expect(
      controller.recentEvents.first.title,
      anyOf(equals('Runtime session active'), equals('Connect requested')),
    );
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
    await Future<void>.delayed(const Duration(milliseconds: 90));
    expect(controller.status.phase, ClientConnectionPhase.connected);

    adapter.setSession(_session(isRunning: false, lastExitCode: 7));
    await Future<void>.delayed(const Duration(milliseconds: 90));

    expect(controller.status.phase, ClientConnectionPhase.error);
    expect(controller.status.message, contains('code 7'));
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
    await Future<void>.delayed(const Duration(milliseconds: 90));
    expect(controller.status.phase, ClientConnectionPhase.connected);

    adapter.setSession(_session(isRunning: false, lastExitCode: 0));
    await Future<void>.delayed(const Duration(milliseconds: 90));

    expect(controller.status.phase, ClientConnectionPhase.disconnected);
    expect(controller.status.message, contains('cleanly'));
  });
}
