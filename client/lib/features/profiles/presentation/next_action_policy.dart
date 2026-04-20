import '../../controller/domain/client_connection_status.dart';
import '../../controller/domain/failure_family.dart';
import '../../readiness/domain/readiness_report.dart';

enum ProfileNextActionType {
  openProfiles,
  openTroubleshooting,
  openSettings,
  retryConnect,
  exportSupportBundle,
  none,
}

class ProfileNextActionDecision {
  const ProfileNextActionDecision({
    required this.type,
    required this.label,
    required this.detail,
  });

  static const ProfileNextActionDecision none = ProfileNextActionDecision(
    type: ProfileNextActionType.none,
    label: 'No action',
    detail: 'No follow-up action is required right now.',
  );

  final ProfileNextActionType type;
  final String label;
  final String detail;

  bool get isActionable => type != ProfileNextActionType.none;

  ReadinessAction? get readinessAction {
    return switch (type) {
      ProfileNextActionType.openProfiles => ReadinessAction.openProfiles,
      ProfileNextActionType.openTroubleshooting =>
        ReadinessAction.openTroubleshooting,
      ProfileNextActionType.openSettings => ReadinessAction.openSettings,
      ProfileNextActionType.retryConnect ||
      ProfileNextActionType.exportSupportBundle ||
      ProfileNextActionType.none => null,
    };
  }
}

class ProfileNextActionPolicy {
  static ProfileNextActionDecision resolve({
    required ClientConnectionStatus status,
    required ReadinessReport? readinessReport,
    required FailureFamily failureFamily,
    required bool troubleshootingAvailable,
    required bool settingsAvailable,
  }) {
    if (readinessReport != null &&
        readinessReport.overallLevel == ReadinessLevel.blocked) {
      return _fromReadiness(
        report: readinessReport,
        troubleshootingAvailable: troubleshootingAvailable,
        settingsAvailable: settingsAvailable,
      );
    }

    if (status.phase == ClientConnectionPhase.error) {
      return _fromFailureFamily(
        failureFamily,
        troubleshootingAvailable: troubleshootingAvailable,
        settingsAvailable: settingsAvailable,
      );
    }

    if (status.phase == ClientConnectionPhase.disconnecting) {
      return troubleshootingAvailable
          ? const ProfileNextActionDecision(
              type: ProfileNextActionType.openTroubleshooting,
              label: 'Open Troubleshooting',
              detail:
                  'Wait for runtime exit confirmation before assuming shutdown has finished.',
            )
          : const ProfileNextActionDecision(
              type: ProfileNextActionType.openProfiles,
              label: 'Open Profiles',
              detail:
                  'Wait for runtime exit confirmation before assuming shutdown has finished.',
            );
    }

    return ProfileNextActionDecision.none;
  }

  static ProfileNextActionDecision _fromReadiness({
    required ReadinessReport report,
    required bool troubleshootingAvailable,
    required bool settingsAvailable,
  }) {
    final recommendation = report.recommendation;
    if (recommendation != null) {
      return switch (recommendation.action) {
        ReadinessAction.openProfiles => ProfileNextActionDecision(
            type: ProfileNextActionType.openProfiles,
            label: recommendation.label,
            detail: recommendation.detail,
          ),
        ReadinessAction.openTroubleshooting => ProfileNextActionDecision(
            type: troubleshootingAvailable
                ? ProfileNextActionType.openTroubleshooting
                : ProfileNextActionType.openProfiles,
            label:
                troubleshootingAvailable ? recommendation.label : 'Open Profiles',
            detail: recommendation.detail,
          ),
        ReadinessAction.openSettings => ProfileNextActionDecision(
            type: settingsAvailable
                ? ProfileNextActionType.openSettings
                : ProfileNextActionType.openProfiles,
            label: settingsAvailable ? recommendation.label : 'Open Profiles',
            detail: recommendation.detail,
          ),
      };
    }

    final blocked = _firstBlockedCheck(report.checks);
    if (blocked == null) {
      return const ProfileNextActionDecision(
        type: ProfileNextActionType.openProfiles,
        label: 'Open Profiles',
        detail: 'Review profile details and retry the connect test.',
      );
    }

    return switch (blocked.domain) {
      ReadinessDomain.password => ProfileNextActionDecision(
          type: ProfileNextActionType.openProfiles,
          label: 'Set Password',
          detail: blocked.detail ?? blocked.summary,
        ),
      ReadinessDomain.profile || ReadinessDomain.config =>
        ProfileNextActionDecision(
          type: ProfileNextActionType.openProfiles,
          label: 'Open Profiles',
          detail: blocked.detail ?? blocked.summary,
        ),
      ReadinessDomain.secureStorage => ProfileNextActionDecision(
          type: settingsAvailable
              ? ProfileNextActionType.openSettings
              : ProfileNextActionType.openProfiles,
          label: settingsAvailable ? 'Open Settings' : 'Open Profiles',
          detail: blocked.detail ?? blocked.summary,
        ),
      ReadinessDomain.environment ||
      ReadinessDomain.runtimePath ||
      ReadinessDomain.runtimeBinary ||
      ReadinessDomain.filesystem =>
        ProfileNextActionDecision(
          type: troubleshootingAvailable
              ? ProfileNextActionType.openTroubleshooting
              : ProfileNextActionType.openProfiles,
          label:
              troubleshootingAvailable ? 'Open Troubleshooting' : 'Open Profiles',
          detail: blocked.detail ?? blocked.summary,
        ),
    };
  }

  static ProfileNextActionDecision _fromFailureFamily(
    FailureFamily family, {
    required bool troubleshootingAvailable,
    required bool settingsAvailable,
  }) {
    return switch (family) {
      FailureFamily.userInput => const ProfileNextActionDecision(
          type: ProfileNextActionType.openProfiles,
          label: 'Set Password',
          detail: 'Save the Trojan password, then retry connect test.',
        ),
      FailureFamily.config => const ProfileNextActionDecision(
          type: ProfileNextActionType.openProfiles,
          label: 'Open Profiles',
          detail: 'Review profile config fields before retrying.',
        ),
      FailureFamily.launch || FailureFamily.connect =>
        const ProfileNextActionDecision(
          type: ProfileNextActionType.retryConnect,
          label: 'Retry Connect Test',
          detail: 'Retry the connect test after preserving current evidence.',
        ),
      FailureFamily.environment => ProfileNextActionDecision(
          type: settingsAvailable
              ? ProfileNextActionType.openSettings
              : (troubleshootingAvailable
                  ? ProfileNextActionType.openTroubleshooting
                  : ProfileNextActionType.openProfiles),
          label: settingsAvailable
              ? 'Open Settings'
              : (troubleshootingAvailable
                  ? 'Open Troubleshooting'
                  : 'Open Profiles'),
          detail:
              'Check runtime environment availability before the next attempt.',
        ),
      FailureFamily.exportOs => const ProfileNextActionDecision(
          type: ProfileNextActionType.exportSupportBundle,
          label: 'Export Support Bundle',
          detail:
              'Capture a support bundle after checking file permissions and target path.',
        ),
      FailureFamily.unknown => ProfileNextActionDecision(
          type: troubleshootingAvailable
              ? ProfileNextActionType.openTroubleshooting
              : ProfileNextActionType.openProfiles,
          label:
              troubleshootingAvailable ? 'Open Troubleshooting' : 'Open Profiles',
          detail:
              'Open Troubleshooting and capture runtime evidence before retrying.',
        ),
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
}
