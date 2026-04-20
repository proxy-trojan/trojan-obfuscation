import '../../readiness/domain/readiness_report.dart';
import 'client_connection_status.dart';
import 'controller_runtime_session.dart';
import 'failure_family.dart';
import 'runtime_posture.dart';

enum RecoveryLadderAction {
  openProfiles,
  openTroubleshooting,
  openSettings,
  retryConnect,
  exportSupportBundle,
  none,
}

enum RecoveryRecentActionContext {
  none,
  connectAttempted,
  retryRequested,
  disconnectRequested,
}

class RecoveryLadderPolicyInput {
  const RecoveryLadderPolicyInput({
    required this.status,
    required this.readinessReport,
    required this.failureFamily,
    required this.runtimePosture,
    required this.runtimeSession,
    required this.recentAction,
    required this.troubleshootingAvailable,
    required this.settingsAvailable,
  });

  final ClientConnectionStatus status;
  final ReadinessReport? readinessReport;
  final FailureFamily failureFamily;
  final RuntimePosture runtimePosture;
  final ControllerRuntimeSession runtimeSession;
  final RecoveryRecentActionContext recentAction;
  final bool troubleshootingAvailable;
  final bool settingsAvailable;
}

class RecoveryLadderDecision {
  const RecoveryLadderDecision({
    required this.primaryAction,
    required this.primaryLabel,
    required this.detail,
    this.secondaryAction,
    this.secondaryLabel,
  });

  static const RecoveryLadderDecision none = RecoveryLadderDecision(
    primaryAction: RecoveryLadderAction.none,
    primaryLabel: 'No action',
    detail: 'No follow-up action is required right now.',
  );

  final RecoveryLadderAction primaryAction;
  final String primaryLabel;
  final String detail;
  final RecoveryLadderAction? secondaryAction;
  final String? secondaryLabel;

  bool get isActionable => primaryAction != RecoveryLadderAction.none;
}

class RecoveryLadderPolicy {
  static RecoveryLadderDecision resolve({
    required RecoveryLadderPolicyInput input,
  }) {
    if (_shouldDriveByReadiness(input.readinessReport, input.status.phase)) {
      return _fromReadiness(
        report: input.readinessReport!,
        troubleshootingAvailable: input.troubleshootingAvailable,
        settingsAvailable: input.settingsAvailable,
      );
    }

    final actionableSessionTruth = _isActionableSessionTruth(
      posture: input.runtimePosture,
      session: input.runtimeSession,
    );

    if (input.status.phase == ClientConnectionPhase.disconnecting ||
        input.runtimeSession.truth == ControllerRuntimeSessionTruth.stopping) {
      return _disconnectingDecision(
        troubleshootingAvailable: input.troubleshootingAvailable,
      );
    }

    if (input.status.phase == ClientConnectionPhase.connected) {
      if (!actionableSessionTruth) {
        return RecoveryLadderDecision.none;
      }
      return RecoveryLadderDecision(
        primaryAction: input.troubleshootingAvailable
            ? RecoveryLadderAction.openTroubleshooting
            : RecoveryLadderAction.openProfiles,
        primaryLabel: input.troubleshootingAvailable
            ? 'Revalidate in Troubleshooting'
            : 'Open Profiles',
        detail:
            'Session truth looks drifted; revalidate runtime evidence before changing state.',
        secondaryAction: input.troubleshootingAvailable
            ? RecoveryLadderAction.openProfiles
            : null,
        secondaryLabel: input.troubleshootingAvailable ? 'Open Profiles' : null,
      );
    }

    if (input.status.phase == ClientConnectionPhase.connecting &&
        actionableSessionTruth) {
      return RecoveryLadderDecision(
        primaryAction: input.troubleshootingAvailable
            ? RecoveryLadderAction.openTroubleshooting
            : RecoveryLadderAction.openProfiles,
        primaryLabel: input.troubleshootingAvailable
            ? 'Open Troubleshooting'
            : 'Open Profiles',
        detail:
            'The connect attempt is still in-flight while runtime evidence is aging; revalidate before retrying.',
      );
    }

    if (input.status.phase == ClientConnectionPhase.error) {
      return _fromFailureFamily(
        family: input.failureFamily,
        troubleshootingAvailable: input.troubleshootingAvailable,
        settingsAvailable: input.settingsAvailable,
        actionableSessionTruth: actionableSessionTruth,
        sessionTruth: input.runtimeSession.truth,
        recentAction: input.recentAction,
      );
    }

    return RecoveryLadderDecision.none;
  }

  static bool _shouldDriveByReadiness(
    ReadinessReport? report,
    ClientConnectionPhase phase,
  ) {
    if (report == null || report.overallLevel != ReadinessLevel.blocked) {
      return false;
    }

    return phase != ClientConnectionPhase.error &&
        phase != ClientConnectionPhase.connected &&
        phase != ClientConnectionPhase.connecting &&
        phase != ClientConnectionPhase.disconnecting;
  }

  static RecoveryLadderDecision _fromReadiness({
    required ReadinessReport report,
    required bool troubleshootingAvailable,
    required bool settingsAvailable,
  }) {
    final recommendation = report.recommendation;
    if (recommendation != null) {
      return switch (recommendation.action) {
        ReadinessAction.openProfiles => RecoveryLadderDecision(
            primaryAction: RecoveryLadderAction.openProfiles,
            primaryLabel: recommendation.label,
            detail: recommendation.detail,
          ),
        ReadinessAction.openTroubleshooting => RecoveryLadderDecision(
            primaryAction: troubleshootingAvailable
                ? RecoveryLadderAction.openTroubleshooting
                : RecoveryLadderAction.openProfiles,
            primaryLabel: troubleshootingAvailable
                ? recommendation.label
                : 'Open Profiles',
            detail: troubleshootingAvailable
                ? recommendation.detail
                : _fallbackDetail(
                    recommendation.detail,
                    fallbackSurface: 'Profiles',
                  ),
          ),
        ReadinessAction.openSettings => RecoveryLadderDecision(
            primaryAction: settingsAvailable
                ? RecoveryLadderAction.openSettings
                : RecoveryLadderAction.openProfiles,
            primaryLabel:
                settingsAvailable ? recommendation.label : 'Open Profiles',
            detail: settingsAvailable
                ? recommendation.detail
                : _fallbackDetail(
                    recommendation.detail,
                    fallbackSurface: 'Profiles',
                  ),
          ),
      };
    }

    final blocked = _firstBlockedCheck(report.checks);
    if (blocked == null) {
      return const RecoveryLadderDecision(
        primaryAction: RecoveryLadderAction.openProfiles,
        primaryLabel: 'Open Profiles',
        detail: 'Review profile details and retry the connect test.',
      );
    }

    return switch (blocked.domain) {
      ReadinessDomain.password => RecoveryLadderDecision(
          primaryAction: RecoveryLadderAction.openProfiles,
          primaryLabel: 'Set Password',
          detail: blocked.detail ?? blocked.summary,
        ),
      ReadinessDomain.profile ||
      ReadinessDomain.config =>
        RecoveryLadderDecision(
          primaryAction: RecoveryLadderAction.openProfiles,
          primaryLabel: 'Open Profiles',
          detail: blocked.detail ?? blocked.summary,
        ),
      ReadinessDomain.secureStorage => RecoveryLadderDecision(
          primaryAction: settingsAvailable
              ? RecoveryLadderAction.openSettings
              : RecoveryLadderAction.openProfiles,
          primaryLabel: settingsAvailable ? 'Open Settings' : 'Open Profiles',
          detail: settingsAvailable
              ? (blocked.detail ?? blocked.summary)
              : _fallbackDetail(
                  blocked.detail ?? blocked.summary,
                  fallbackSurface: 'Profiles',
                ),
        ),
      ReadinessDomain.environment ||
      ReadinessDomain.runtimePath ||
      ReadinessDomain.runtimeBinary ||
      ReadinessDomain.filesystem =>
        RecoveryLadderDecision(
          primaryAction: troubleshootingAvailable
              ? RecoveryLadderAction.openTroubleshooting
              : RecoveryLadderAction.openProfiles,
          primaryLabel: troubleshootingAvailable
              ? 'Open Troubleshooting'
              : 'Open Profiles',
          detail: troubleshootingAvailable
              ? (blocked.detail ?? blocked.summary)
              : _fallbackDetail(
                  blocked.detail ?? blocked.summary,
                  fallbackSurface: 'Profiles',
                ),
        ),
    };
  }

  static RecoveryLadderDecision _disconnectingDecision({
    required bool troubleshootingAvailable,
  }) {
    return RecoveryLadderDecision(
      primaryAction: troubleshootingAvailable
          ? RecoveryLadderAction.openTroubleshooting
          : RecoveryLadderAction.openProfiles,
      primaryLabel:
          troubleshootingAvailable ? 'Open Troubleshooting' : 'Open Profiles',
      detail:
          'Do not treat this runtime as fully closed yet. Wait for runtime exit confirmation before assuming shutdown has finished.',
      secondaryAction:
          troubleshootingAvailable ? RecoveryLadderAction.openProfiles : null,
      secondaryLabel: troubleshootingAvailable ? 'Open Profiles' : null,
    );
  }

  static RecoveryLadderDecision _fromFailureFamily({
    required FailureFamily family,
    required bool troubleshootingAvailable,
    required bool settingsAvailable,
    required bool actionableSessionTruth,
    required ControllerRuntimeSessionTruth sessionTruth,
    required RecoveryRecentActionContext recentAction,
  }) {
    switch (family) {
      case FailureFamily.userInput:
        return const RecoveryLadderDecision(
          primaryAction: RecoveryLadderAction.openProfiles,
          primaryLabel: 'Set Password',
          detail: 'Save the Trojan password, then retry connect test.',
        );
      case FailureFamily.config:
        return const RecoveryLadderDecision(
          primaryAction: RecoveryLadderAction.openProfiles,
          primaryLabel: 'Open Profiles',
          detail: 'Review profile config fields before retrying.',
        );
      case FailureFamily.connect:
      case FailureFamily.launch:
        final evidenceFirst = _shouldCaptureEvidenceFirst(
          actionableSessionTruth: actionableSessionTruth,
          sessionTruth: sessionTruth,
          recentAction: recentAction,
        );
        if (evidenceFirst) {
          return RecoveryLadderDecision(
            primaryAction: troubleshootingAvailable
                ? RecoveryLadderAction.openTroubleshooting
                : RecoveryLadderAction.openProfiles,
            primaryLabel: troubleshootingAvailable
                ? 'Open Troubleshooting'
                : 'Open Profiles',
            detail:
                'Preserve current runtime evidence before retrying the connect path.',
          );
        }
        return const RecoveryLadderDecision(
          primaryAction: RecoveryLadderAction.retryConnect,
          primaryLabel: 'Retry Connect Test',
          detail: 'Retry the connect test after preserving current evidence.',
        );
      case FailureFamily.environment:
        return RecoveryLadderDecision(
          primaryAction: settingsAvailable
              ? RecoveryLadderAction.openSettings
              : (troubleshootingAvailable
                  ? RecoveryLadderAction.openTroubleshooting
                  : RecoveryLadderAction.openProfiles),
          primaryLabel: settingsAvailable
              ? 'Open Settings'
              : (troubleshootingAvailable
                  ? 'Open Troubleshooting'
                  : 'Open Profiles'),
          detail:
              'Check runtime environment availability before the next attempt.',
        );
      case FailureFamily.exportOs:
        return const RecoveryLadderDecision(
          primaryAction: RecoveryLadderAction.exportSupportBundle,
          primaryLabel: 'Export Support Bundle',
          detail:
              'Capture a support bundle after checking file permissions and target path.',
        );
      case FailureFamily.unknown:
        return RecoveryLadderDecision(
          primaryAction: troubleshootingAvailable
              ? RecoveryLadderAction.openTroubleshooting
              : RecoveryLadderAction.openProfiles,
          primaryLabel: troubleshootingAvailable
              ? 'Open Troubleshooting'
              : 'Open Profiles',
          detail:
              'Open Troubleshooting and capture runtime evidence before retrying.',
        );
    }
  }

  static bool _isActionableSessionTruth({
    required RuntimePosture posture,
    required ControllerRuntimeSession session,
  }) {
    return session.needsAttention &&
        (!posture.isStubOnly || session.isRunning || session.stopRequested);
  }

  static bool _shouldCaptureEvidenceFirst({
    required bool actionableSessionTruth,
    required ControllerRuntimeSessionTruth sessionTruth,
    required RecoveryRecentActionContext recentAction,
  }) {
    if (!actionableSessionTruth) {
      return false;
    }

    if (recentAction == RecoveryRecentActionContext.retryRequested ||
        recentAction == RecoveryRecentActionContext.disconnectRequested) {
      return true;
    }

    return switch (sessionTruth) {
      ControllerRuntimeSessionTruth.stopping => true,
      ControllerRuntimeSessionTruth.aging => true,
      ControllerRuntimeSessionTruth.stale => true,
      ControllerRuntimeSessionTruth.residual => true,
      ControllerRuntimeSessionTruth.live => false,
      ControllerRuntimeSessionTruth.stopped => false,
    };
  }

  static ReadinessCheck? _firstBlockedCheck(List<ReadinessCheck> checks) {
    for (final check in checks) {
      if (check.level == ReadinessLevel.blocked) {
        return check;
      }
    }
    return null;
  }

  static String _fallbackDetail(
    String sourceDetail, {
    required String fallbackSurface,
  }) {
    return 'fallback to $fallbackSurface: $sourceDetail';
  }
}
