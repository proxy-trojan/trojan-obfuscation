import 'client_connection_status.dart';
import 'controller_command_result.dart';
import 'controller_runtime_session.dart';
import 'runtime_posture.dart';

enum RuntimeActionKind {
  connect,
  retry,
  disconnect,
}

String buildRuntimeActionFeedback({
  required RuntimeActionKind action,
  required ControllerCommandResult result,
  required ClientConnectionStatus status,
  required ControllerRuntimeSession session,
  required RuntimePosture posture,
}) {
  if (!result.accepted) {
    return result.summary;
  }

  switch (action) {
    case RuntimeActionKind.connect:
    case RuntimeActionKind.retry:
      if (status.phase == ClientConnectionPhase.connected) {
        if (posture.isStubOnly &&
            !session.isRunning &&
            session.truth == ControllerRuntimeSessionTruth.residual) {
          return 'Connected on the current ${posture.postureLabel.toLowerCase()} path. Shell validation is ready.';
        }
        if (session.needsAttention) {
          return 'Connection completed, but the runtime state still needs attention: ${session.recoveryGuidance}';
        }
        return posture.isRuntimeTrue
            ? 'Connected on the runtime-true path. Runtime evidence looks current.'
            : 'Connected on the current ${posture.postureLabel.toLowerCase()} path. Shell validation is ready.';
      }

      if (status.phase == ClientConnectionPhase.connecting) {
        return '${result.summary} ${session.recoveryGuidance}';
      }

      return result.summary;

    case RuntimeActionKind.disconnect:
      if (status.phase == ClientConnectionPhase.disconnecting) {
        return session.stopRequested
            ? 'Disconnect requested. Wait for exit confirmation before trusting the session as closed.'
            : 'Disconnect requested. The runtime is still winding down.';
      }

      if (status.phase == ClientConnectionPhase.disconnected) {
        return session.truth == ControllerRuntimeSessionTruth.residual
            ? 'Disconnected, but residual runtime state still needs cleanup in Troubleshooting.'
            : 'Disconnected cleanly.';
      }

      return result.summary;
  }
}
