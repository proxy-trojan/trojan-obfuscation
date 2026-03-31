import 'client_connection_status.dart';
import 'controller_runtime_session.dart';
import 'runtime_action_safety.dart';
import 'runtime_operator_advice.dart';
import 'runtime_posture.dart';

enum RuntimePrimaryActionContract {
  keepCurrentPrimary,
  preferTroubleshooting,
}

enum RuntimeSecondaryStateChangeContract {
  allowFallback,
  withholdFallback,
}

enum RuntimeEvidenceCaptureContract {
  optional,
  preferBeforeMutation,
}

enum RuntimeRetryContract {
  allowShortcut,
  blockShortcut,
}

enum RuntimeNextStepContract {
  none,
  openTroubleshooting,
  captureSupportEvidence,
}

enum RuntimePreferredOperatorAction {
  none,
  openTroubleshooting,
}

enum RuntimePreferredEvidenceAction {
  none,
  generateSupportPreview,
  exportSupportBundle,
}

class RuntimeActionMatrix {
  const RuntimeActionMatrix({
    required this.actionSafety,
    required this.operatorAdvice,
    required this.primaryActionContract,
    required this.secondaryStateChangeContract,
    required this.evidenceCaptureContract,
    required this.retryContract,
    required this.nextStepContract,
    required this.preferredOperatorAction,
    required this.preferredEvidenceAction,
  });

  final RuntimeActionSafety actionSafety;
  final RuntimeOperatorAdvice operatorAdvice;
  final RuntimePrimaryActionContract primaryActionContract;
  final RuntimeSecondaryStateChangeContract secondaryStateChangeContract;
  final RuntimeEvidenceCaptureContract evidenceCaptureContract;
  final RuntimeRetryContract retryContract;
  final RuntimeNextStepContract nextStepContract;
  final RuntimePreferredOperatorAction preferredOperatorAction;
  final RuntimePreferredEvidenceAction preferredEvidenceAction;

  bool get preferTroubleshootingPrimary =>
      primaryActionContract == RuntimePrimaryActionContract.preferTroubleshooting;

  bool get withholdSecondaryStateChangingActions =>
      secondaryStateChangeContract ==
      RuntimeSecondaryStateChangeContract.withholdFallback;

  bool get preferSnapshotFirst =>
      evidenceCaptureContract ==
      RuntimeEvidenceCaptureContract.preferBeforeMutation;

  bool get blockRetryShortcut =>
      retryContract == RuntimeRetryContract.blockShortcut;

  bool get showExitConfirmationWarning =>
      actionSafety.state == RuntimeActionSafetyState.waitForExitConfirmation;

  static RuntimeActionMatrix resolve({
    required ClientConnectionStatus status,
    required ControllerRuntimeSession session,
    required RuntimePosture posture,
    required bool troubleshootingAvailable,
  }) {
    final actionSafety = RuntimeActionSafety.resolve(
      status: status,
      session: session,
      posture: posture,
    );
    final operatorAdvice = RuntimeOperatorAdvice.resolve(
      status: status,
      session: session,
      posture: posture,
      troubleshootingAvailable: troubleshootingAvailable,
    );

    return RuntimeActionMatrix.fromResolved(
      actionSafety: actionSafety,
      operatorAdvice: operatorAdvice,
    );
  }

  factory RuntimeActionMatrix.fromResolved({
    required RuntimeActionSafety actionSafety,
    required RuntimeOperatorAdvice operatorAdvice,
  }) {
    return RuntimeActionMatrix(
      actionSafety: actionSafety,
      operatorAdvice: operatorAdvice,
      primaryActionContract:
          operatorAdvice.actionableSessionTruth && operatorAdvice.primaryEnabled
              ? RuntimePrimaryActionContract.preferTroubleshooting
              : RuntimePrimaryActionContract.keepCurrentPrimary,
      secondaryStateChangeContract:
          actionSafety.state == RuntimeActionSafetyState.waitForExitConfirmation
              ? RuntimeSecondaryStateChangeContract.withholdFallback
              : RuntimeSecondaryStateChangeContract.allowFallback,
      evidenceCaptureContract: actionSafety.recommendsSnapshotFirst
          ? RuntimeEvidenceCaptureContract.preferBeforeMutation
          : RuntimeEvidenceCaptureContract.optional,
      retryContract: actionSafety.blocksRetry
          ? RuntimeRetryContract.blockShortcut
          : RuntimeRetryContract.allowShortcut,
      nextStepContract:
          actionSafety.state == RuntimeActionSafetyState.waitForExitConfirmation
              ? RuntimeNextStepContract.captureSupportEvidence
              : operatorAdvice.actionableSessionTruth
                  ? RuntimeNextStepContract.openTroubleshooting
                  : RuntimeNextStepContract.none,
      preferredOperatorAction:
          operatorAdvice.actionableSessionTruth && operatorAdvice.primaryEnabled
              ? RuntimePreferredOperatorAction.openTroubleshooting
              : RuntimePreferredOperatorAction.none,
      preferredEvidenceAction:
          actionSafety.state == RuntimeActionSafetyState.waitForExitConfirmation ||
                  actionSafety.state ==
                      RuntimeActionSafetyState.captureSnapshotFirst
              ? RuntimePreferredEvidenceAction.generateSupportPreview
              : RuntimePreferredEvidenceAction.none,
    );
  }
}
