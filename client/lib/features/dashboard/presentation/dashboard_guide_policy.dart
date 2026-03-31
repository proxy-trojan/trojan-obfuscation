import '../../controller/domain/client_connection_status.dart';
import '../../controller/domain/controller_runtime_session.dart';
import '../../controller/domain/runtime_action_matrix.dart';
import '../../controller/domain/runtime_action_safety.dart';
import '../../controller/domain/runtime_operator_advice.dart';
import '../../controller/domain/runtime_posture.dart';
import '../../profiles/domain/client_profile.dart';
import '../../readiness/domain/readiness_report.dart';
import '../application/connection_lifecycle_view_model.dart';

enum DashboardGuideAction {
  openProfiles,
  openAdvanced,
  openSettings,
  connectNow,
  retryNow,
  disconnectNow,
}

class DashboardGuidePolicy {
  const DashboardGuidePolicy({
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.primaryAction,
    required this.actionSafety,
    this.secondaryLabel,
    this.secondaryAction,
    this.operatorTitle,
    this.operatorBody,
  });

  final String title;
  final String body;
  final String primaryLabel;
  final DashboardGuideAction primaryAction;
  final RuntimeActionSafety actionSafety;
  final String? secondaryLabel;
  final DashboardGuideAction? secondaryAction;
  final String? operatorTitle;
  final String? operatorBody;

  static DashboardGuidePolicy resolve({
    required ConnectionLifecycleViewModel lifecycle,
    required ClientProfile? selectedProfile,
    required ClientProfile? activeProfile,
    required ClientConnectionStatus status,
    required RuntimePosture posture,
    required ControllerRuntimeSession runtimeSession,
    required RuntimeOperatorAdvice operatorAdvice,
    required ReadinessReport? readiness,
  }) {
    final actionSafety = RuntimeActionSafety.resolve(
      status: status,
      session: runtimeSession,
      posture: posture,
    );
    final actionMatrix = RuntimeActionMatrix.fromResolved(
      actionSafety: actionSafety,
      operatorAdvice: operatorAdvice,
    );

    if (selectedProfile == null && activeProfile == null) {
      return DashboardGuidePolicy(
        title: 'Start by adding one profile',
        body:
            'Create or import a profile first. Once that exists, the rest of the flow becomes much simpler.',
        primaryLabel: 'Open Profiles',
        primaryAction: DashboardGuideAction.openProfiles,
        actionSafety: actionSafety,
      );
    }

    if (activeProfile == null &&
        selectedProfile != null &&
        !selectedProfile.hasStoredPassword) {
      return DashboardGuidePolicy(
        title: 'Save the password before testing',
        body:
            'The selected profile still needs its Trojan password. Save it first, then try one connection attempt.',
        primaryLabel: 'Open Profiles',
        primaryAction: DashboardGuideAction.openProfiles,
        actionSafety: actionSafety,
      );
    }

    if (readiness != null &&
        readiness.overallLevel == ReadinessLevel.blocked &&
        status.phase != ClientConnectionPhase.error &&
        status.phase != ClientConnectionPhase.connected &&
        status.phase != ClientConnectionPhase.connecting &&
        status.phase != ClientConnectionPhase.disconnecting) {
      final recommendation = readiness.recommendation;
      return DashboardGuidePolicy(
        title: readiness.headline,
        body: readiness.summary,
        primaryLabel: recommendation?.label ?? 'Open Troubleshooting',
        primaryAction: recommendation == null
            ? DashboardGuideAction.openAdvanced
            : _guideActionFor(recommendation.action),
        actionSafety: actionSafety,
        secondaryLabel: 'Open Profiles',
        secondaryAction: DashboardGuideAction.openProfiles,
      );
    }

    if (status.phase == ClientConnectionPhase.error) {
      final errorBody = operatorAdvice.actionableSessionTruth
          ? operatorAdvice.message ??
              '${lifecycle.detail} ${runtimeSession.recoveryGuidance}'
          : lifecycle.detail;
      final evidenceFirst = actionMatrix.preferredEvidenceAction ==
          RuntimePreferredEvidenceAction.generateSupportPreview;
      return DashboardGuidePolicy(
        title: lifecycle.headline,
        body: errorBody,
        primaryLabel: evidenceFirst
            ? (operatorAdvice.primaryLabel ?? 'Open Troubleshooting')
            : lifecycle.showRetry
                ? posture.qualifyAction('Retry now')
                : 'Open Profiles',
        primaryAction: evidenceFirst
            ? (actionMatrix.preferredOperatorAction ==
                    RuntimePreferredOperatorAction.openTroubleshooting
                ? DashboardGuideAction.openAdvanced
                : DashboardGuideAction.openProfiles)
            : lifecycle.showRetry
                ? DashboardGuideAction.retryNow
                : DashboardGuideAction.openProfiles,
        actionSafety: actionSafety,
        secondaryLabel: evidenceFirst
            ? null
            : lifecycle.showOpenTroubleshooting
                ? 'Open Troubleshooting'
                : null,
        secondaryAction: evidenceFirst
            ? null
            : lifecycle.showOpenTroubleshooting
                ? DashboardGuideAction.openAdvanced
                : null,
        operatorTitle: evidenceFirst
            ? 'Recommended right now: capture a support snapshot first'
            : null,
        operatorBody: evidenceFirst
            ? 'Open Troubleshooting and preserve the current runtime evidence before retrying. A fast retry now may erase the signal that explains this failure.'
            : null,
      );
    }

    if (status.phase == ClientConnectionPhase.connected) {
      if (operatorAdvice.actionableSessionTruth) {
        return DashboardGuidePolicy(
          title: operatorAdvice.headline ?? 'Connection state needs revalidation',
          body: operatorAdvice.message ??
              '${runtimeSession.truthNote} ${runtimeSession.recoveryGuidance}',
          primaryLabel: operatorAdvice.primaryLabel ?? 'Open Troubleshooting',
          primaryAction: actionMatrix.preferredOperatorAction ==
                  RuntimePreferredOperatorAction.openTroubleshooting
              ? DashboardGuideAction.openAdvanced
              : DashboardGuideAction.openProfiles,
          actionSafety: actionSafety,
          secondaryLabel: actionMatrix.secondaryStateChangeContract ==
                  RuntimeSecondaryStateChangeContract.withholdFallback
              ? null
              : 'Disconnect now',
          secondaryAction: actionMatrix.secondaryStateChangeContract ==
                  RuntimeSecondaryStateChangeContract.withholdFallback
              ? null
              : DashboardGuideAction.disconnectNow,
          operatorTitle: 'Recommended right now',
          operatorBody: actionMatrix.nextStepContract ==
                  RuntimeNextStepContract.openTroubleshooting
              ? 'Open Troubleshooting first, confirm whether the session is still trustworthy, and only then decide whether to disconnect or reconnect.'
              : 'Review the current runtime state before making another state-changing move.',
        );
      }
      return DashboardGuidePolicy(
        title: 'Connection is active',
        body:
            'You are already connected. Disconnect here if you want to end the current session, or open Profiles to switch context.',
        primaryLabel: 'Disconnect now',
        primaryAction: DashboardGuideAction.disconnectNow,
        actionSafety: actionSafety,
        secondaryLabel: 'Open Profiles',
        secondaryAction: DashboardGuideAction.openProfiles,
      );
    }

    if (status.phase == ClientConnectionPhase.disconnecting) {
      return DashboardGuidePolicy(
        title: operatorAdvice.headline ?? lifecycle.headline,
        body: operatorAdvice.message ?? lifecycle.detail,
        primaryLabel: operatorAdvice.primaryLabel ?? 'Open Troubleshooting',
        primaryAction: actionMatrix.preferredOperatorAction ==
                RuntimePreferredOperatorAction.openTroubleshooting
            ? DashboardGuideAction.openAdvanced
            : DashboardGuideAction.openProfiles,
        actionSafety: actionSafety,
        secondaryLabel: 'Open Profiles',
        secondaryAction: DashboardGuideAction.openProfiles,
        operatorTitle: actionMatrix.evidenceCaptureContract ==
                RuntimeEvidenceCaptureContract.preferBeforeMutation
            ? 'Recommended right now: capture a support snapshot first'
            : 'Recommended right now',
        operatorBody: actionMatrix.nextStepContract ==
                RuntimeNextStepContract.captureSupportEvidence
            ? 'Open Troubleshooting and capture the current support evidence before you retry or assume shutdown has finished. This keeps the stop-pending state visible while it is still fresh.'
            : 'Open Troubleshooting before making another change.',
      );
    }

    if (status.phase == ClientConnectionPhase.connecting) {
      return DashboardGuidePolicy(
        title: lifecycle.headline,
        body: operatorAdvice.message ?? lifecycle.detail,
        primaryLabel: operatorAdvice.primaryLabel ?? 'Open Troubleshooting',
        primaryAction: actionMatrix.preferredOperatorAction ==
                RuntimePreferredOperatorAction.openTroubleshooting
            ? DashboardGuideAction.openAdvanced
            : DashboardGuideAction.openProfiles,
        actionSafety: actionSafety,
        secondaryLabel: 'Open Profiles',
        secondaryAction: DashboardGuideAction.openProfiles,
        operatorTitle: 'Recommended right now',
        operatorBody:
            'Let the current connection attempt settle first. If the runtime keeps looking suspicious, open Troubleshooting before retrying again.',
      );
    }

    return DashboardGuidePolicy(
      title: 'You are ready for a quick test',
      body:
          'Use one clear Connect action here, or open Profiles if you want to review the selected profile first.',
      primaryLabel: posture.qualifyAction('Connect now'),
      primaryAction: DashboardGuideAction.connectNow,
      actionSafety: actionSafety,
      secondaryLabel: 'Open Profiles',
      secondaryAction: DashboardGuideAction.openProfiles,
    );
  }

  static DashboardGuideAction _guideActionFor(ReadinessAction action) {
    return switch (action) {
      ReadinessAction.openProfiles => DashboardGuideAction.openProfiles,
      ReadinessAction.openTroubleshooting => DashboardGuideAction.openAdvanced,
      ReadinessAction.openSettings => DashboardGuideAction.openSettings,
    };
  }
}
