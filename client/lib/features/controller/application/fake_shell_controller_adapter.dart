import '../domain/controller_command.dart';
import '../domain/controller_command_result.dart';
import '../domain/controller_runtime_config.dart';
import '../domain/controller_runtime_health.dart';
import '../domain/controller_runtime_session.dart';
import '../domain/controller_telemetry_snapshot.dart';
import 'shell_controller_adapter.dart';

class FakeShellControllerAdapter implements ShellControllerAdapter {
  FakeShellControllerAdapter({
    this.backendKind = 'fake-shell-controller',
    this.backendVersion = 'dev-shell',
    this.runtimeMode = 'stubbed-local-boundary',
    this.endpointHint = 'in-process://fake-shell-controller',
  });

  final String backendKind;
  final String backendVersion;
  final String runtimeMode;
  final String endpointHint;

  final DateTime _sessionUpdatedAt = DateTime.now();

  @override
  ControllerTelemetrySnapshot get telemetry => ControllerTelemetrySnapshot(
        backendKind: backendKind,
        backendVersion: backendVersion,
        capabilities: const <String>[
          'connect',
          'disconnect',
          'collectDiagnostics',
          'prepareExport',
        ],
        lastUpdatedAt: DateTime.now(),
      );

  @override
  ControllerRuntimeConfig get runtimeConfig => ControllerRuntimeConfig(
        mode: runtimeMode,
        endpointHint: endpointHint,
        enableVerboseTelemetry: true,
      );

  @override
  ControllerRuntimeSession get session => ControllerRuntimeSession(
        isRunning: false,
        updatedAt: _sessionUpdatedAt,
        phase: ControllerRuntimePhase.sessionReady,
        configProvenance: 'simulated://fake-shell-controller',
        lastExitCode: 0,
        stdoutTail: const <String>['fake controller session active'],
      );

  @override
  Future<ControllerRuntimeHealth> checkHealth() async {
    return ControllerRuntimeHealth(
      level: ControllerRuntimeHealthLevel.healthy,
      summary:
          'Fake shell controller adapter is available for product-layer validation.',
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<ControllerCommandResult> execute(ControllerCommand command) async {
    final bundleKind = command.arguments['bundleKind']?.toString();
    return ControllerCommandResult(
      commandId: command.id,
      accepted: true,
      completedAt: DateTime.now(),
      summary: 'Fake shell adapter accepted ${command.kind.name}.',
      details: <String, Object?>{
        'kind': command.kind.name,
        if (bundleKind != null)
          'details': <String, Object?>{
            'bundleKind': bundleKind,
            'evidenceClass': 'shell-demo-only',
          },
      },
    );
  }
}
