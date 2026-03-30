import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/controller/domain/client_connection_status.dart';
import 'package:trojan_pro_client/features/controller/domain/controller_command_result.dart';
import 'package:trojan_pro_client/features/controller/domain/controller_runtime_session.dart';
import 'package:trojan_pro_client/features/controller/domain/runtime_action_feedback.dart';
import 'package:trojan_pro_client/features/controller/domain/runtime_posture.dart';

void main() {
  test('connect feedback mentions shell validation on stub posture', () {
    final feedback = buildRuntimeActionFeedback(
      action: RuntimeActionKind.connect,
      result: ControllerCommandResult(
        commandId: 'connect-1',
        accepted: true,
        completedAt: DateTime.now(),
        summary: 'Connection flow completed in fake controller boundary.',
      ),
      status: ClientConnectionStatus(
        phase: ClientConnectionPhase.connected,
        message: 'Connected via fake controller boundary',
        updatedAt: DateTime.now(),
        activeProfileId: 'sample-hk-1',
      ),
      session: ControllerRuntimeSession(
        isRunning: false,
        updatedAt: DateTime.now(),
        phase: ControllerRuntimePhase.sessionReady,
      ),
      posture: describeRuntimePosture(
        runtimeMode: 'stubbed-local-boundary',
        backendKind: 'fake-shell-controller',
      ),
    );

    expect(feedback, contains('Shell validation is ready'));
  });

  test('disconnect feedback asks for exit confirmation while stop is pending', () {
    final feedback = buildRuntimeActionFeedback(
      action: RuntimeActionKind.disconnect,
      result: ControllerCommandResult(
        commandId: 'disconnect-1',
        accepted: true,
        completedAt: DateTime.now(),
        summary: 'Requested trojan client shutdown for pid=4242.',
      ),
      status: ClientConnectionStatus(
        phase: ClientConnectionPhase.disconnecting,
        message: 'Stop requested.',
        updatedAt: DateTime.now(),
        activeProfileId: 'sample-hk-1',
      ),
      session: ControllerRuntimeSession(
        isRunning: true,
        updatedAt: DateTime.now(),
        phase: ControllerRuntimePhase.alive,
        stopRequested: true,
        stopRequestedAt: DateTime.now(),
        pid: 4242,
      ),
      posture: describeRuntimePosture(
        runtimeMode: 'real-runtime-boundary',
        backendKind: 'real-shell-controller',
      ),
    );

    expect(feedback, contains('Wait for exit confirmation'));
  });
}
