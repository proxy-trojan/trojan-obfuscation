import '../../controller/domain/client_connection_status.dart';
import '../../controller/domain/controller_runtime_session.dart';
import '../../controller/domain/failure_family.dart';
import '../../controller/domain/recovery_ladder_policy.dart';
import '../../controller/domain/runtime_posture.dart';
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
      ProfileNextActionType.none =>
        null,
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
    RuntimePosture? runtimePosture,
    ControllerRuntimeSession? runtimeSession,
    RecoveryRecentActionContext recentAction = RecoveryRecentActionContext.none,
  }) {
    final decision = RecoveryLadderPolicy.resolve(
      input: RecoveryLadderPolicyInput(
        status: status,
        readinessReport: readinessReport,
        failureFamily: failureFamily,
        runtimePosture: runtimePosture ??
            describeRuntimePosture(
              runtimeMode: 'stubbed-local-boundary',
              backendKind: 'legacy-profile-next-action',
            ),
        runtimeSession: runtimeSession ??
            ControllerRuntimeSession(
              isRunning: false,
              updatedAt: DateTime.now(),
              phase: ControllerRuntimePhase.stopped,
            ),
        recentAction: recentAction,
        troubleshootingAvailable: troubleshootingAvailable,
        settingsAvailable: settingsAvailable,
      ),
    );

    return ProfileNextActionDecision(
      type: _mapType(decision.primaryAction),
      label: decision.primaryLabel,
      detail: decision.detail,
    );
  }

  static ProfileNextActionType _mapType(RecoveryLadderAction action) {
    return switch (action) {
      RecoveryLadderAction.openProfiles => ProfileNextActionType.openProfiles,
      RecoveryLadderAction.openTroubleshooting =>
        ProfileNextActionType.openTroubleshooting,
      RecoveryLadderAction.openSettings => ProfileNextActionType.openSettings,
      RecoveryLadderAction.retryConnect => ProfileNextActionType.retryConnect,
      RecoveryLadderAction.exportSupportBundle =>
        ProfileNextActionType.exportSupportBundle,
      RecoveryLadderAction.none => ProfileNextActionType.none,
    };
  }
}
