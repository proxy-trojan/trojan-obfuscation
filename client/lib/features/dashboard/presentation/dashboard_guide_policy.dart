import '../../controller/domain/client_connection_status.dart';
import '../../controller/domain/controller_runtime_session.dart';
import '../../controller/domain/failure_family.dart';
import '../../controller/domain/recovery_ladder_policy.dart';
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
    required bool settingsAvailable,
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

    final profileContext = activeProfile ?? selectedProfile;
    if (profileContext == null) {
      return DashboardGuidePolicy(
        title: 'Start by adding one profile',
        body: 'Open Profiles and create one profile before testing.',
        primaryLabel: 'Open Profiles',
        primaryAction: DashboardGuideAction.openProfiles,
        actionSafety: actionSafety,
      );
    }

    if (activeProfile == null && !profileContext.hasStoredPassword) {
      return DashboardGuidePolicy(
        title: 'Save the password before testing',
        body:
            'The selected profile still needs its Trojan password. Save it first, then try one connection attempt.',
        primaryLabel: 'Open Profiles',
        primaryAction: DashboardGuideAction.openProfiles,
        actionSafety: actionSafety,
      );
    }

    final parsedFamily = parseFailureFamily(status.failureFamilyHint);
    final failureFamily = parsedFamily == FailureFamily.unknown
        ? classifyFailureFamily(
            errorCode: status.errorCode,
            summary: status.message,
            detail: status.message,
            phase: status.phase.name,
          )
        : parsedFamily;

    final ladderDecision = RecoveryLadderPolicy.resolve(
      input: RecoveryLadderPolicyInput(
        status: status,
        readinessReport: readiness,
        failureFamily: failureFamily,
        runtimePosture: posture,
        runtimeSession: runtimeSession,
        recentAction: _recentActionFor(status),
        troubleshootingAvailable: operatorAdvice.primaryEnabled,
        settingsAvailable: settingsAvailable,
      ),
    );

    final guideAction = _mapLadderAction(ladderDecision.primaryAction);

    if (status.phase == ClientConnectionPhase.connected &&
        !operatorAdvice.actionableSessionTruth) {
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

    if (status.phase == ClientConnectionPhase.disconnected &&
        readiness?.overallLevel != ReadinessLevel.blocked) {
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

    final body = status.phase == ClientConnectionPhase.error
        ? ladderDecision.detail
        : (operatorAdvice.message ?? ladderDecision.detail);

    final title = status.phase == ClientConnectionPhase.connected
        ? (operatorAdvice.headline ?? 'Connection state needs revalidation')
        : status.phase == ClientConnectionPhase.disconnecting
            ? (operatorAdvice.headline ?? lifecycle.headline)
            : status.phase == ClientConnectionPhase.connecting
                ? lifecycle.headline
                : status.phase == ClientConnectionPhase.error
                    ? lifecycle.headline
                    : (readiness?.headline ?? lifecycle.headline);

    final secondaryAction = _secondaryActionFor(
      status: status,
      actionMatrix: actionMatrix,
      ladderDecision: ladderDecision,
    );

    return DashboardGuidePolicy(
      title: title,
      body: body,
      primaryLabel: ladderDecision.primaryLabel,
      primaryAction: guideAction,
      actionSafety: actionSafety,
      secondaryLabel: secondaryAction?.$1,
      secondaryAction: secondaryAction?.$2,
      operatorTitle: _operatorTitleFor(
        status: status,
        actionMatrix: actionMatrix,
        operatorAdvice: operatorAdvice,
      ),
      operatorBody: _operatorBodyFor(
        status: status,
        actionMatrix: actionMatrix,
      ),
    );
  }

  static RecoveryRecentActionContext _recentActionFor(
    ClientConnectionStatus status,
  ) {
    return switch (status.phase) {
      ClientConnectionPhase.connecting =>
        RecoveryRecentActionContext.connectAttempted,
      ClientConnectionPhase.disconnecting =>
        RecoveryRecentActionContext.disconnectRequested,
      ClientConnectionPhase.error => RecoveryRecentActionContext.retryRequested,
      ClientConnectionPhase.connected ||
      ClientConnectionPhase.disconnected =>
        RecoveryRecentActionContext.none,
    };
  }

  static DashboardGuideAction _mapLadderAction(RecoveryLadderAction action) {
    return switch (action) {
      RecoveryLadderAction.openProfiles => DashboardGuideAction.openProfiles,
      RecoveryLadderAction.openTroubleshooting =>
        DashboardGuideAction.openAdvanced,
      RecoveryLadderAction.openSettings => DashboardGuideAction.openSettings,
      RecoveryLadderAction.retryConnect => DashboardGuideAction.retryNow,
      RecoveryLadderAction.exportSupportBundle =>
        DashboardGuideAction.openAdvanced,
      RecoveryLadderAction.none => DashboardGuideAction.openProfiles,
    };
  }

  static (String, DashboardGuideAction)? _secondaryActionFor({
    required ClientConnectionStatus status,
    required RuntimeActionMatrix actionMatrix,
    required RecoveryLadderDecision ladderDecision,
  }) {
    if (status.phase == ClientConnectionPhase.connected &&
        actionMatrix.secondaryStateChangeContract !=
            RuntimeSecondaryStateChangeContract.withholdFallback) {
      return ('Disconnect now', DashboardGuideAction.disconnectNow);
    }

    if (ladderDecision.secondaryAction != null) {
      return (
        ladderDecision.secondaryLabel ?? 'Open Profiles',
        _mapLadderAction(ladderDecision.secondaryAction!),
      );
    }

    if (status.phase == ClientConnectionPhase.disconnected ||
        status.phase == ClientConnectionPhase.connecting ||
        status.phase == ClientConnectionPhase.disconnecting) {
      return ('Open Profiles', DashboardGuideAction.openProfiles);
    }

    return null;
  }

  static String? _operatorTitleFor({
    required ClientConnectionStatus status,
    required RuntimeActionMatrix actionMatrix,
    required RuntimeOperatorAdvice operatorAdvice,
  }) {
    if (status.phase == ClientConnectionPhase.error &&
        actionMatrix.preferredEvidenceAction ==
            RuntimePreferredEvidenceAction.generateSupportPreview) {
      return 'Recommended right now: capture a support snapshot first';
    }

    if (status.phase == ClientConnectionPhase.disconnecting &&
        actionMatrix.evidenceCaptureContract ==
            RuntimeEvidenceCaptureContract.preferBeforeMutation) {
      return 'Recommended right now: capture a support snapshot first';
    }

    if (status.phase == ClientConnectionPhase.connected &&
        operatorAdvice.actionableSessionTruth) {
      return 'Recommended right now';
    }

    if (status.phase == ClientConnectionPhase.connecting) {
      return 'Recommended right now';
    }

    return null;
  }

  static String? _operatorBodyFor({
    required ClientConnectionStatus status,
    required RuntimeActionMatrix actionMatrix,
  }) {
    if (status.phase == ClientConnectionPhase.error &&
        actionMatrix.preferredEvidenceAction ==
            RuntimePreferredEvidenceAction.generateSupportPreview) {
      return 'Open Troubleshooting and preserve the current runtime evidence before retrying. A fast retry now may erase the signal that explains this failure.';
    }

    if (status.phase == ClientConnectionPhase.disconnecting &&
        actionMatrix.nextStepContract ==
            RuntimeNextStepContract.captureSupportEvidence) {
      return 'Open Troubleshooting and capture the current support evidence before you retry or assume shutdown has finished. This keeps the stop-pending state visible while it is still fresh.';
    }

    if (status.phase == ClientConnectionPhase.connected &&
        actionMatrix.nextStepContract ==
            RuntimeNextStepContract.openTroubleshooting) {
      return 'Open Troubleshooting first, confirm whether the session is still trustworthy, and only then decide whether to disconnect or reconnect.';
    }

    if (status.phase == ClientConnectionPhase.connecting) {
      return 'Let the current connection attempt settle first. If the runtime keeps looking suspicious, open Troubleshooting before retrying again.';
    }

    return null;
  }
}
