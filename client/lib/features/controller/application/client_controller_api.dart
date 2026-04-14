import 'package:flutter/foundation.dart';

import '../../profiles/domain/client_profile.dart';
import '../domain/client_connection_status.dart';
import '../domain/client_controller_event.dart';
import '../domain/controller_command_result.dart';
import '../domain/controller_runtime_config.dart';
import '../domain/controller_runtime_health.dart';
import '../domain/controller_runtime_session.dart';
import '../domain/controller_telemetry_snapshot.dart';
import '../domain/last_runtime_failure_summary.dart';

abstract class ClientControllerApi extends ChangeNotifier {
  ClientConnectionStatus get status;

  List<ClientControllerEvent> get recentEvents;

  ControllerTelemetrySnapshot get telemetry;

  ControllerRuntimeConfig get runtimeConfig;

  ControllerRuntimeSession get session;
  LastRuntimeFailureSummary? get lastRuntimeFailure;

  Future<ControllerRuntimeHealth> checkHealth();

  Future<ControllerCommandResult> connect(ClientProfile profile);

  Future<ControllerCommandResult> disconnect();

  Future<ControllerCommandResult> collectDiagnostics({
    required String bundleKind,
  }) async {
    return ControllerCommandResult(
      commandId: 'collect-diagnostics-unsupported',
      accepted: false,
      completedAt: DateTime.now(),
      summary: 'This controller boundary does not expose runtime diagnostics.',
      error: 'UNSUPPORTED',
      details: <String, Object?>{
        'bundleKind': bundleKind,
      },
    );
  }

  Future<ControllerCommandResult> prepareExport({
    required String bundleKind,
  }) async {
    return ControllerCommandResult(
      commandId: 'prepare-export-unsupported',
      accepted: false,
      completedAt: DateTime.now(),
      summary: 'This controller boundary does not expose export preparation.',
      error: 'UNSUPPORTED',
      details: <String, Object?>{
        'bundleKind': bundleKind,
      },
    );
  }
}
