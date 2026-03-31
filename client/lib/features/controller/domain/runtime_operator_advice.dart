import 'client_connection_status.dart';
import 'controller_runtime_session.dart';
import 'runtime_posture.dart';

enum RuntimeOperatorAdviceKind {
  none,
  revalidateInTroubleshooting,
  waitForExitConfirmation,
}

class RuntimeOperatorAdvice {
  const RuntimeOperatorAdvice({
    required this.kind,
    required this.actionableSessionTruth,
    required this.headline,
    required this.message,
    required this.primaryLabel,
    required this.primaryEnabled,
  });

  final RuntimeOperatorAdviceKind kind;
  final bool actionableSessionTruth;
  final String? headline;
  final String? message;
  final String? primaryLabel;
  final bool primaryEnabled;

  static const RuntimeOperatorAdvice none = RuntimeOperatorAdvice(
    kind: RuntimeOperatorAdviceKind.none,
    actionableSessionTruth: false,
    headline: null,
    message: null,
    primaryLabel: null,
    primaryEnabled: false,
  );

  static RuntimeOperatorAdvice resolve({
    required ClientConnectionStatus status,
    required ControllerRuntimeSession session,
    required RuntimePosture posture,
    required bool troubleshootingAvailable,
  }) {
    final actionableSessionTruth = session.needsAttention &&
        (!posture.isStubOnly || session.isRunning || session.stopRequested);

    if (!actionableSessionTruth) {
      return none;
    }

    if (status.phase == ClientConnectionPhase.connected) {
      return RuntimeOperatorAdvice(
        kind: RuntimeOperatorAdviceKind.revalidateInTroubleshooting,
        actionableSessionTruth: true,
        headline: 'Connection state needs revalidation',
        message: '${session.truthNote} ${session.recoveryGuidance}',
        primaryLabel: 'Open Troubleshooting',
        primaryEnabled: troubleshootingAvailable,
      );
    }

    if (status.phase == ClientConnectionPhase.disconnecting ||
        session.truth == ControllerRuntimeSessionTruth.stopping) {
      return RuntimeOperatorAdvice(
        kind: RuntimeOperatorAdviceKind.waitForExitConfirmation,
        actionableSessionTruth: true,
        headline: 'Exit confirmation pending',
        message:
            'Do not treat this runtime as fully closed yet. ${session.recoveryGuidance}',
        primaryLabel: 'Open Troubleshooting',
        primaryEnabled: troubleshootingAvailable,
      );
    }

    if (status.phase == ClientConnectionPhase.connecting ||
        status.phase == ClientConnectionPhase.error) {
      return RuntimeOperatorAdvice(
        kind: RuntimeOperatorAdviceKind.revalidateInTroubleshooting,
        actionableSessionTruth: true,
        headline: null,
        message: session.recoveryGuidance,
        primaryLabel: 'Open Troubleshooting',
        primaryEnabled: troubleshootingAvailable,
      );
    }

    return none;
  }
}
