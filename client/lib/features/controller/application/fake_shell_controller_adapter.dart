import '../domain/controller_command.dart';
import '../domain/controller_command_result.dart';
import '../domain/controller_runtime_config.dart';
import '../domain/controller_runtime_health.dart';
import '../domain/controller_runtime_session.dart';
import '../domain/controller_telemetry_snapshot.dart';
import 'shell_controller_adapter.dart';

class FakeShellControllerAdapter implements ShellControllerAdapter {
  final DateTime _sessionUpdatedAt = DateTime.now();
  @override
  ControllerTelemetrySnapshot get telemetry => ControllerTelemetrySnapshot(
        backendKind: 'fake-shell-controller',
        backendVersion: 'dev-shell',
        capabilities: const <String>[
          'connect',
          'disconnect',
          'collectDiagnostics',
          'prepareExport',
        ],
        lastUpdatedAt: DateTime.now(),
      );

  @override
  ControllerRuntimeConfig get runtimeConfig => const ControllerRuntimeConfig(
        mode: 'stubbed-local-boundary',
        endpointHint: 'in-process://fake-shell-controller',
        enableVerboseTelemetry: true,
      );

  @override
  ControllerRuntimeSession get session => ControllerRuntimeSession(
        isRunning: false,
        updatedAt: _sessionUpdatedAt,
        lastExitCode: 0,
        stdoutTail: const <String>['fake controller session active'],
      );

  @override
  Future<ControllerRuntimeHealth> checkHealth() async {
    return ControllerRuntimeHealth(
      level: ControllerRuntimeHealthLevel.healthy,
      summary: 'Fake shell controller adapter is available for product-layer validation.',
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<ControllerCommandResult> execute(ControllerCommand command) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return ControllerCommandResult(
      commandId: command.id,
      accepted: true,
      completedAt: DateTime.now(),
      summary: 'Fake shell adapter accepted ${command.kind.name}.',
    );
  }
}
