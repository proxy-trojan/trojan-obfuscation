import '../../controller/domain/client_connection_status.dart';
import '../../controller/domain/controller_runtime_session.dart';
import '../../controller/domain/runtime_action_matrix.dart';
import '../../controller/domain/runtime_action_safety.dart';
import '../../controller/domain/runtime_operator_advice.dart';
import '../../controller/domain/runtime_posture.dart';

class DiagnosticsSupportPolicy {
  const DiagnosticsSupportPolicy({
    required this.currentTruthTitle,
    required this.currentTruthSubtitle,
    required this.currentTruthMessage,
    required this.actionSafety,
    required this.showExitConfirmationWarning,
    required this.exitConfirmationTitle,
    required this.exitConfirmationBody,
    required this.primaryOperatorTitle,
    required this.primaryOperatorBody,
    required this.preferredEvidenceActionLabel,
    required this.postureGuidance,
    required this.exportSnapshotLabel,
    required this.exportSnapshotDetail,
  });

  final String currentTruthTitle;
  final String currentTruthSubtitle;
  final String currentTruthMessage;
  final RuntimeActionSafety actionSafety;
  final bool showExitConfirmationWarning;
  final String? exitConfirmationTitle;
  final String? exitConfirmationBody;
  final String primaryOperatorTitle;
  final String primaryOperatorBody;
  final String? preferredEvidenceActionLabel;
  final String postureGuidance;
  final String? exportSnapshotLabel;
  final String? exportSnapshotDetail;

  static DiagnosticsSupportPolicy resolve({
    required ControllerRuntimeSession runtimeSession,
    required RuntimePosture runtimePosture,
    required RuntimeOperatorAdvice operatorAdvice,
    required ControllerRuntimeSession? exportedRuntimeSession,
    required String? exportedBundleKindLabel,
  }) {
    final exportSnapshotAdvice = exportedRuntimeSession == null
        ? RuntimeOperatorAdvice.none
        : RuntimeOperatorAdvice.resolve(
            status: ClientConnectionStatus(
              phase: exportedRuntimeSession.truth ==
                      ControllerRuntimeSessionTruth.stopping
                  ? ClientConnectionPhase.disconnecting
                  : ClientConnectionPhase.connected,
              message: exportedRuntimeSession.truthNote,
              updatedAt: exportedRuntimeSession.updatedAt,
              activeProfileId: null,
            ),
            session: exportedRuntimeSession,
            posture: runtimePosture,
            troubleshootingAvailable: true,
          );

    final actionSafety = RuntimeActionSafety.resolve(
      status: ClientConnectionStatus(
        phase: runtimeSession.truth == ControllerRuntimeSessionTruth.stopping
            ? ClientConnectionPhase.disconnecting
            : ClientConnectionPhase.connected,
        message: runtimeSession.truthNote,
        updatedAt: runtimeSession.updatedAt,
        activeProfileId: null,
      ),
      session: runtimeSession,
      posture: runtimePosture,
    );
    final actionMatrix = RuntimeActionMatrix.fromResolved(
      actionSafety: actionSafety,
      operatorAdvice: operatorAdvice,
    );

    return DiagnosticsSupportPolicy(
      currentTruthTitle: 'Current runtime truth: ${runtimeSession.truth.label}',
      currentTruthSubtitle: runtimeSession.truthNote,
      currentTruthMessage:
          operatorAdvice.message ?? runtimeSession.recoveryGuidance,
      actionSafety: actionSafety,
      showExitConfirmationWarning: actionMatrix.secondaryStateChangeContract ==
          RuntimeSecondaryStateChangeContract.withholdFallback,
      exitConfirmationTitle:
          operatorAdvice.headline ?? 'Exit confirmation pending',
      exitConfirmationBody: operatorAdvice.message ??
          'Do not treat this runtime as fully closed yet. Wait for exit confirmation or export the current support snapshot before retrying.',
      primaryOperatorTitle: actionMatrix.evidenceCaptureContract ==
              RuntimeEvidenceCaptureContract.preferBeforeMutation
          ? 'Recommended right now: capture a support snapshot first'
          : 'Recommended right now',
      primaryOperatorBody: actionMatrix.nextStepContract ==
              RuntimeNextStepContract.captureSupportEvidence
          ? 'Generate a support preview or export a support bundle before you retry or assume shutdown has finished. This preserves the stop-pending evidence while it is still current.'
          : 'Use the preview/export actions below to capture the current runtime evidence before making bigger changes.',
      preferredEvidenceActionLabel:
          actionMatrix.preferredEvidenceAction ==
                  RuntimePreferredEvidenceAction.generateSupportPreview
              ? 'Generate support preview'
              : actionMatrix.preferredEvidenceAction ==
                      RuntimePreferredEvidenceAction.exportSupportBundle
                  ? 'Export support bundle'
                  : null,
      postureGuidance: runtimePosture.isRuntimeTrue
          ? 'This posture can contribute runtime-true evidence if the snapshot stays current.'
          : 'This posture is still ${runtimePosture.postureLabel.toLowerCase()}, so export the bundle as support context rather than proof of a real runtime path.',
      exportSnapshotLabel: exportedRuntimeSession == null
          ? null
          : '${exportedBundleKindLabel ?? 'latest export'} captured ${exportedRuntimeSession.truth.label}',
      exportSnapshotDetail: exportedRuntimeSession == null
          ? null
          : 'Export snapshot age at capture: ${exportedRuntimeSession.ageLabel}. ${exportSnapshotAdvice.message ?? exportedRuntimeSession.recoveryGuidance}',
    );
  }
}
