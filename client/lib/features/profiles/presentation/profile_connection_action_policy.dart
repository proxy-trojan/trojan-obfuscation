import '../../controller/domain/client_connection_status.dart';
import '../../controller/domain/controller_runtime_session.dart';
import '../../controller/domain/runtime_action_matrix.dart';
import '../../controller/domain/runtime_action_safety.dart';
import '../../controller/domain/runtime_operator_advice.dart';
import '../../controller/domain/runtime_posture.dart';
import '../../readiness/domain/readiness_report.dart';

enum ProfileConnectionPrimaryAction {
  connect,
  disconnect,
  openTroubleshooting,
  none,
}

class ProfileConnectionActionPolicy {
  const ProfileConnectionActionPolicy({
    required this.canToggleConnection,
    required this.buttonEnabled,
    required this.buttonLabel,
    required this.statusHint,
    required this.primaryAction,
    required this.actionableSessionTruth,
    required this.actionSafety,
  });

  final bool canToggleConnection;
  final bool buttonEnabled;
  final String buttonLabel;
  final String statusHint;
  final ProfileConnectionPrimaryAction primaryAction;
  final bool actionableSessionTruth;
  final RuntimeActionSafety actionSafety;

  static ProfileConnectionActionPolicy resolve({
    required bool hasStoredPassword,
    required bool active,
    required ClientConnectionStatus status,
    required RuntimePosture runtimePosture,
    required ControllerRuntimeSession runtimeSession,
    required ReadinessReport? readinessReport,
    required bool hasConnectedElsewhere,
    required bool onOpenAdvancedAvailable,
  }) {
    final connectBlockedByReadiness = readinessReport != null &&
        readinessReport.overallLevel == ReadinessLevel.blocked &&
        !(active && status.phase == ClientConnectionPhase.connected);

    final actionSafety = RuntimeActionSafety.resolve(
      status: status,
      session: runtimeSession,
      posture: runtimePosture,
    );
    final operatorAdvice = active
        ? RuntimeOperatorAdvice.resolve(
            status: status,
            session: runtimeSession,
            posture: runtimePosture,
            troubleshootingAvailable: onOpenAdvancedAvailable,
          )
        : RuntimeOperatorAdvice.none;
    final actionMatrix = RuntimeActionMatrix.fromResolved(
      actionSafety: actionSafety,
      operatorAdvice: operatorAdvice,
    );
    final actionableSessionTruth = operatorAdvice.actionableSessionTruth;

    if (!hasStoredPassword) {
      return ProfileConnectionActionPolicy(
        canToggleConnection: false,
        buttonEnabled: false,
        buttonLabel: 'Set Password First',
        statusHint: 'Save the Trojan password before trying this profile.',
        primaryAction: ProfileConnectionPrimaryAction.none,
        actionableSessionTruth: false,
        actionSafety: actionSafety,
      );
    }

    if (hasConnectedElsewhere) {
      return ProfileConnectionActionPolicy(
        canToggleConnection: false,
        buttonEnabled: false,
        buttonLabel: 'Connected Elsewhere',
        statusHint:
            'Another profile is already connected. Disconnect it before switching here.',
        primaryAction: ProfileConnectionPrimaryAction.none,
        actionableSessionTruth: false,
        actionSafety: actionSafety,
      );
    }

    if (connectBlockedByReadiness) {
      return ProfileConnectionActionPolicy(
        canToggleConnection: false,
        buttonEnabled: false,
        buttonLabel: 'Connect Blocked',
        statusHint: 'Readiness blocked: ${readinessReport.summary}',
        primaryAction: ProfileConnectionPrimaryAction.none,
        actionableSessionTruth: actionableSessionTruth,
        actionSafety: actionSafety,
      );
    }

    if (active && status.phase == ClientConnectionPhase.connected) {
      if (actionableSessionTruth) {
        return ProfileConnectionActionPolicy(
          canToggleConnection: false,
          buttonEnabled: actionMatrix.primaryActionContract ==
              RuntimePrimaryActionContract.preferTroubleshooting,
          buttonLabel:
              operatorAdvice.kind == RuntimeOperatorAdviceKind.revalidateInTroubleshooting
                  ? 'Revalidate in Troubleshooting'
                  : (operatorAdvice.primaryLabel ?? 'Open Troubleshooting'),
          statusHint: operatorAdvice.message ??
              '${runtimeSession.truthNote} ${runtimeSession.recoveryGuidance}',
          primaryAction: actionMatrix.preferredOperatorAction ==
                  RuntimePreferredOperatorAction.openTroubleshooting
              ? ProfileConnectionPrimaryAction.openTroubleshooting
              : ProfileConnectionPrimaryAction.none,
          actionableSessionTruth: true,
          actionSafety: actionSafety,
        );
      }

      return ProfileConnectionActionPolicy(
        canToggleConnection: true,
        buttonEnabled: true,
        buttonLabel: 'Disconnect',
        statusHint: 'Connected via fake controller boundary',
        primaryAction: ProfileConnectionPrimaryAction.disconnect,
        actionableSessionTruth: false,
        actionSafety: actionSafety,
      );
    }

    if (active && status.phase == ClientConnectionPhase.connecting) {
      return ProfileConnectionActionPolicy(
        canToggleConnection: false,
        buttonEnabled: false,
        buttonLabel: 'Connecting...',
        statusHint: operatorAdvice.message ??
            'This profile is still establishing a runtime session.',
        primaryAction: ProfileConnectionPrimaryAction.none,
        actionableSessionTruth: actionableSessionTruth,
        actionSafety: actionSafety,
      );
    }

    if (active && status.phase == ClientConnectionPhase.disconnecting) {
      return ProfileConnectionActionPolicy(
        canToggleConnection: false,
        buttonEnabled: actionMatrix.primaryActionContract ==
            RuntimePrimaryActionContract.preferTroubleshooting,
        buttonLabel: actionMatrix.primaryActionContract ==
                RuntimePrimaryActionContract.preferTroubleshooting
            ? (operatorAdvice.primaryLabel ?? 'Open Troubleshooting')
            : 'Disconnecting...',
        statusHint: operatorAdvice.message ??
            'This profile is disconnecting now. Wait for the shutdown to finish.',
        primaryAction: actionMatrix.preferredOperatorAction ==
                RuntimePreferredOperatorAction.openTroubleshooting
            ? ProfileConnectionPrimaryAction.openTroubleshooting
            : ProfileConnectionPrimaryAction.none,
        actionableSessionTruth: actionableSessionTruth,
        actionSafety: actionSafety,
      );
    }

    return ProfileConnectionActionPolicy(
      canToggleConnection: true,
      buttonEnabled: true,
      buttonLabel: runtimePosture.qualifyAction('Connect'),
      statusHint: status.message,
      primaryAction: ProfileConnectionPrimaryAction.connect,
      actionableSessionTruth: actionableSessionTruth,
      actionSafety: actionSafety,
    );
  }
}
