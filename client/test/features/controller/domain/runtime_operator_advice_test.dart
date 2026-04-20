import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/controller/domain/client_connection_status.dart';
import 'package:trojan_pro_client/features/controller/domain/controller_runtime_session.dart';
import 'package:trojan_pro_client/features/controller/domain/runtime_operator_advice.dart';
import 'package:trojan_pro_client/features/controller/domain/runtime_posture.dart';

void main() {
  test('connected stale runtime recommends revalidation', () {
    final advice = RuntimeOperatorAdvice.resolve(
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

    expect(advice.kind, RuntimeOperatorAdviceKind.revalidateInTroubleshooting);
    expect(advice.headline, 'Connection state needs revalidation');
    expect(advice.primaryEnabled, isTrue);
  });

  test(
      'disconnecting stop-pending runtime recommends waiting for exit confirmation',
      () {
    final advice = RuntimeOperatorAdvice.resolve(
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

    expect(advice.kind, RuntimeOperatorAdviceKind.waitForExitConfirmation);
    expect(advice.headline, 'Exit confirmation pending');
    expect(advice.message, contains('fully closed yet'));
  });

  test(
      'error residual session recommends troubleshooting evidence-first guidance',
      () {
    final advice = RuntimeOperatorAdvice.resolve(
      status: ClientConnectionStatus(
        phase: ClientConnectionPhase.error,
        message: 'Runtime process exited unexpectedly.',
        updatedAt: DateTime.now(),
        activeProfileId: 'sample-hk-1',
      ),
      session: ControllerRuntimeSession(
        isRunning: false,
        updatedAt: DateTime.now().subtract(const Duration(seconds: 40)),
        phase: ControllerRuntimePhase.failed,
        lastExitCode: 7,
      ),
      posture: describeRuntimePosture(
        runtimeMode: 'real-runtime-boundary',
        backendKind: 'real-shell-controller',
      ),
      troubleshootingAvailable: true,
    );

    expect(advice.kind, RuntimeOperatorAdviceKind.revalidateInTroubleshooting);
    expect(advice.primaryEnabled, isTrue);
    expect(advice.primaryLabel, 'Open Troubleshooting');
    expect(advice.message, contains('leftover session state'));
  });

  test('error stale running session still advises troubleshooting before retry',
      () {
    final advice = RuntimeOperatorAdvice.resolve(
      status: ClientConnectionStatus(
        phase: ClientConnectionPhase.error,
        message: 'Handshake timed out.',
        updatedAt: DateTime.now(),
        activeProfileId: 'sample-hk-1',
      ),
      session: ControllerRuntimeSession(
        isRunning: true,
        updatedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        phase: ControllerRuntimePhase.alive,
      ),
      posture: describeRuntimePosture(
        runtimeMode: 'real-runtime-boundary',
        backendKind: 'real-shell-controller',
      ),
      troubleshootingAvailable: true,
    );

    expect(advice.kind, RuntimeOperatorAdviceKind.revalidateInTroubleshooting);
    expect(advice.primaryEnabled, isTrue);
    expect(advice.message, contains('Open Troubleshooting'));
  });

  test('stub residual state does not create actionable advice by itself', () {
    final advice = RuntimeOperatorAdvice.resolve(
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

    expect(advice.kind, RuntimeOperatorAdviceKind.none);
    expect(advice.actionableSessionTruth, isFalse);
  });
}
