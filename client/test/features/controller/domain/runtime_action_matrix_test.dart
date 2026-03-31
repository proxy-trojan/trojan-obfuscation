import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/controller/domain/client_connection_status.dart';
import 'package:trojan_pro_client/features/controller/domain/controller_runtime_session.dart';
import 'package:trojan_pro_client/features/controller/domain/runtime_action_matrix.dart';
import 'package:trojan_pro_client/features/controller/domain/runtime_posture.dart';

void main() {
  test('stale connected runtime prefers troubleshooting without withholding manual fallback', () {
    final matrix = RuntimeActionMatrix.resolve(
      status: ClientConnectionStatus(
        phase: ClientConnectionPhase.connected,
        message: 'Runtime session is ready.',
        updatedAt: DateTime.now(),
        activeProfileId: 'sample-hk-1',
      ),
      session: ControllerRuntimeSession(
        isRunning: true,
        updatedAt: DateTime.now().subtract(const Duration(minutes: 3)),
        phase: ControllerRuntimePhase.sessionReady,
      ),
      posture: describeRuntimePosture(
        runtimeMode: 'real-runtime-boundary',
        backendKind: 'real-shell-controller',
      ),
      troubleshootingAvailable: true,
    );

    expect(matrix.primaryActionContract,
        RuntimePrimaryActionContract.preferTroubleshooting);
    expect(matrix.secondaryStateChangeContract,
        RuntimeSecondaryStateChangeContract.allowFallback);
    expect(matrix.evidenceCaptureContract,
        RuntimeEvidenceCaptureContract.optional);
    expect(matrix.retryContract, RuntimeRetryContract.blockShortcut);
    expect(matrix.nextStepContract,
        RuntimeNextStepContract.openTroubleshooting);
    expect(matrix.preferredOperatorAction,
        RuntimePreferredOperatorAction.openTroubleshooting);
    expect(matrix.preferredEvidenceAction, RuntimePreferredEvidenceAction.none);
    expect(matrix.preferTroubleshootingPrimary, isTrue);
    expect(matrix.withholdSecondaryStateChangingActions, isFalse);
    expect(matrix.preferSnapshotFirst, isFalse);
    expect(matrix.blockRetryShortcut, isTrue);
    expect(matrix.showExitConfirmationWarning, isFalse);
  });

  test('stop-pending runtime prefers snapshot-first and withholds secondary state changes', () {
    final matrix = RuntimeActionMatrix.resolve(
      status: ClientConnectionStatus(
        phase: ClientConnectionPhase.disconnecting,
        message: 'Disconnecting current session...',
        updatedAt: DateTime.now(),
        activeProfileId: 'sample-hk-1',
      ),
      session: ControllerRuntimeSession(
        isRunning: true,
        updatedAt: DateTime.now().subtract(const Duration(seconds: 8)),
        phase: ControllerRuntimePhase.alive,
        stopRequested: true,
        stopRequestedAt: DateTime.now().subtract(const Duration(seconds: 4)),
      ),
      posture: describeRuntimePosture(
        runtimeMode: 'real-runtime-boundary',
        backendKind: 'real-shell-controller',
      ),
      troubleshootingAvailable: true,
    );

    expect(matrix.primaryActionContract,
        RuntimePrimaryActionContract.preferTroubleshooting);
    expect(matrix.secondaryStateChangeContract,
        RuntimeSecondaryStateChangeContract.withholdFallback);
    expect(matrix.evidenceCaptureContract,
        RuntimeEvidenceCaptureContract.preferBeforeMutation);
    expect(matrix.retryContract, RuntimeRetryContract.blockShortcut);
    expect(matrix.nextStepContract,
        RuntimeNextStepContract.captureSupportEvidence);
    expect(matrix.preferredOperatorAction,
        RuntimePreferredOperatorAction.openTroubleshooting);
    expect(matrix.preferTroubleshootingPrimary, isTrue);
    expect(matrix.withholdSecondaryStateChangingActions, isTrue);
    expect(matrix.preferSnapshotFirst, isTrue);
    expect(matrix.blockRetryShortcut, isTrue);
    expect(matrix.showExitConfirmationWarning, isTrue);
  });

  test('stub residual state does not create operator gating by itself', () {
    final matrix = RuntimeActionMatrix.resolve(
      status: ClientConnectionStatus(
        phase: ClientConnectionPhase.connected,
        message: 'Connected via fake controller boundary',
        updatedAt: DateTime.now(),
        activeProfileId: 'sample-hk-1',
      ),
      session: ControllerRuntimeSession(
        isRunning: false,
        updatedAt: DateTime.now(),
        phase: ControllerRuntimePhase.sessionReady,
      ),
      posture: describeRuntimePosture(
        runtimeMode: 'stubbed-local-boundary',
        backendKind: 'fake-shell-controller',
      ),
      troubleshootingAvailable: true,
    );

    expect(matrix.primaryActionContract,
        RuntimePrimaryActionContract.keepCurrentPrimary);
    expect(matrix.secondaryStateChangeContract,
        RuntimeSecondaryStateChangeContract.allowFallback);
    expect(matrix.evidenceCaptureContract,
        RuntimeEvidenceCaptureContract.optional);
    expect(matrix.retryContract, RuntimeRetryContract.allowShortcut);
    expect(matrix.nextStepContract, RuntimeNextStepContract.none);
    expect(matrix.preferredOperatorAction, RuntimePreferredOperatorAction.none);
    expect(matrix.preferredEvidenceAction, RuntimePreferredEvidenceAction.none);
    expect(matrix.preferTroubleshootingPrimary, isFalse);
    expect(matrix.withholdSecondaryStateChangingActions, isFalse);
    expect(matrix.preferSnapshotFirst, isFalse);
    expect(matrix.blockRetryShortcut, isFalse);
    expect(matrix.showExitConfirmationWarning, isFalse);
  });
}
