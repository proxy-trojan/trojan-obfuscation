import '../domain/controller_command.dart';
import '../domain/controller_command_result.dart';
import '../domain/controller_runtime_config.dart';
import '../domain/controller_runtime_health.dart';
import '../domain/controller_runtime_session.dart';
import '../domain/controller_telemetry_snapshot.dart';

abstract class ShellControllerAdapter {
  ControllerTelemetrySnapshot get telemetry;

  ControllerRuntimeConfig get runtimeConfig;

  ControllerRuntimeSession get session;

  Future<ControllerRuntimeHealth> checkHealth();

  Future<ControllerCommandResult> execute(ControllerCommand command);
}
