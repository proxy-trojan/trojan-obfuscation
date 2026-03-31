import 'client_connection_status.dart';
import 'controller_runtime_session.dart';
import 'runtime_posture.dart';

enum RuntimeActionSafetyState {
  safeToProceed,
  revalidateFirst,
  captureSnapshotFirst,
  waitForExitConfirmation,
}

class RuntimeActionSafety {
  const RuntimeActionSafety({
    required this.state,
    required this.label,
    required this.detail,
  });

  final RuntimeActionSafetyState state;
  final String label;
  final String detail;

  bool get blocksRetry => switch (state) {
        RuntimeActionSafetyState.safeToProceed => false,
        RuntimeActionSafetyState.revalidateFirst => true,
        RuntimeActionSafetyState.captureSnapshotFirst => true,
        RuntimeActionSafetyState.waitForExitConfirmation => true,
      };

  bool get recommendsSnapshotFirst => switch (state) {
        RuntimeActionSafetyState.captureSnapshotFirst => true,
        RuntimeActionSafetyState.waitForExitConfirmation => true,
        RuntimeActionSafetyState.safeToProceed => false,
        RuntimeActionSafetyState.revalidateFirst => false,
      };

  static RuntimeActionSafety resolve({
    required ClientConnectionStatus status,
    required ControllerRuntimeSession session,
    required RuntimePosture posture,
  }) {
    final actionableSessionTruth = session.needsAttention &&
        (!posture.isStubOnly || session.isRunning || session.stopRequested);

    if (!actionableSessionTruth) {
      return const RuntimeActionSafety(
        state: RuntimeActionSafetyState.safeToProceed,
        label: 'Safe to proceed',
        detail: 'No extra action-safety guardrail is required right now.',
      );
    }

    if (status.phase == ClientConnectionPhase.disconnecting ||
        session.truth == ControllerRuntimeSessionTruth.stopping) {
      return const RuntimeActionSafety(
        state: RuntimeActionSafetyState.waitForExitConfirmation,
        label: 'Wait for exit confirmation',
        detail:
            'Do not retry or assume the runtime is closed yet. Capture support evidence first, then wait for exit confirmation.',
      );
    }

    if (status.phase == ClientConnectionPhase.connected) {
      return const RuntimeActionSafety(
        state: RuntimeActionSafetyState.revalidateFirst,
        label: 'Revalidate before changing state',
        detail:
            'Open Troubleshooting first and confirm the runtime is still trustworthy before disconnecting or reconnecting.',
      );
    }

    if (status.phase == ClientConnectionPhase.connecting ||
        status.phase == ClientConnectionPhase.error) {
      return const RuntimeActionSafety(
        state: RuntimeActionSafetyState.captureSnapshotFirst,
        label: 'Capture snapshot before retry',
        detail:
            'Preserve the current runtime evidence before you retry, otherwise you may lose the signal that explains the failure.',
      );
    }

    return const RuntimeActionSafety(
      state: RuntimeActionSafetyState.safeToProceed,
      label: 'Safe to proceed',
      detail: 'No extra action-safety guardrail is required right now.',
    );
  }
}
