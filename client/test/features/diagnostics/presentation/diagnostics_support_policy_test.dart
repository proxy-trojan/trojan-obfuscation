import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/controller/domain/client_connection_status.dart';
import 'package:trojan_pro_client/features/controller/domain/controller_runtime_session.dart';
import 'package:trojan_pro_client/features/controller/domain/runtime_operator_advice.dart';
import 'package:trojan_pro_client/features/controller/domain/runtime_posture.dart';
import 'package:trojan_pro_client/features/diagnostics/presentation/diagnostics_support_policy.dart';

void main() {
  test('stopping runtime surfaces exit confirmation warning', () {
    final runtimeSession = ControllerRuntimeSession(
      isRunning: true,
      updatedAt: DateTime.now().subtract(const Duration(seconds: 12)),
      phase: ControllerRuntimePhase.alive,
      stopRequested: true,
      stopRequestedAt: DateTime.now().subtract(const Duration(seconds: 6)),
    );
    final posture = describeRuntimePosture(
      runtimeMode: 'real-runtime-boundary',
      backendKind: 'real-shell-controller',
    );
    final advice = RuntimeOperatorAdvice.resolve(
      status: ClientConnectionStatus(
        phase: ClientConnectionPhase.disconnecting,
        message: 'Disconnecting current session...',
        updatedAt: DateTime.now(),
        activeProfileId: 'sample-hk-1',
      ),
      session: runtimeSession,
      posture: posture,
      troubleshootingAvailable: true,
    );

    final policy = DiagnosticsSupportPolicy.resolve(
      runtimeSession: runtimeSession,
      runtimePosture: posture,
      operatorAdvice: advice,
      exportedRuntimeSession: null,
      exportedBundleKindLabel: null,
    );

    expect(policy.showExitConfirmationWarning, isTrue);
    expect(policy.exitConfirmationTitle, 'Exit confirmation pending');
    expect(policy.exitConfirmationBody, contains('fully closed yet'));
    expect(policy.primaryOperatorTitle,
        'Recommended right now: capture a support snapshot first');
    expect(policy.primaryOperatorBody, contains('support preview'));
    expect(policy.preferredEvidenceActionLabel, 'Generate support preview');
  });

  test('export snapshot detail reuses shared operator semantics', () {
    final runtimeSession = ControllerRuntimeSession(
      isRunning: false,
      updatedAt: DateTime.now(),
      phase: ControllerRuntimePhase.stopped,
    );
    final exportedSession = ControllerRuntimeSession(
      isRunning: true,
      updatedAt: DateTime.now().subtract(const Duration(minutes: 3)),
      phase: ControllerRuntimePhase.sessionReady,
    );
    final posture = describeRuntimePosture(
      runtimeMode: 'real-runtime-boundary',
      backendKind: 'real-shell-controller',
    );

    final policy = DiagnosticsSupportPolicy.resolve(
      runtimeSession: runtimeSession,
      runtimePosture: posture,
      operatorAdvice: RuntimeOperatorAdvice.none,
      exportedRuntimeSession: exportedSession,
      exportedBundleKindLabel: 'support bundle',
    );

    expect(policy.exportSnapshotLabel, 'support bundle captured Stale');
    expect(policy.exportSnapshotDetail, contains('revalidate'));
  });
}
