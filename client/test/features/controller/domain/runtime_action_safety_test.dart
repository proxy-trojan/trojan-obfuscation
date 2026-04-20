import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/controller/domain/client_connection_status.dart';
import 'package:trojan_pro_client/features/controller/domain/controller_runtime_session.dart';
import 'package:trojan_pro_client/features/controller/domain/runtime_action_safety.dart';
import 'package:trojan_pro_client/features/controller/domain/runtime_posture.dart';

void main() {
  test(
      'disconnecting stop-pending runtime blocks retry until exit confirmation',
      () {
    final safety = RuntimeActionSafety.resolve(
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
    );

    expect(safety.state, RuntimeActionSafetyState.waitForExitConfirmation);
    expect(safety.blocksRetry, isTrue);
    expect(safety.recommendsSnapshotFirst, isTrue);
    expect(safety.detail, contains('Capture support evidence first'));
  });

  test('stale connected runtime requires revalidation before state changes',
      () {
    final safety = RuntimeActionSafety.resolve(
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
    );

    expect(safety.state, RuntimeActionSafetyState.revalidateFirst);
    expect(safety.blocksRetry, isTrue);
    expect(safety.recommendsSnapshotFirst, isFalse);
  });

  test('error residual runtime enforces evidence capture before retry', () {
    final safety = RuntimeActionSafety.resolve(
      status: ClientConnectionStatus(
        phase: ClientConnectionPhase.error,
        message: 'Runtime session exited unexpectedly.',
        updatedAt: DateTime.now(),
        activeProfileId: 'sample-hk-1',
      ),
      session: ControllerRuntimeSession(
        isRunning: false,
        updatedAt: DateTime.now().subtract(const Duration(seconds: 45)),
        phase: ControllerRuntimePhase.failed,
        lastExitCode: 13,
      ),
      posture: describeRuntimePosture(
        runtimeMode: 'real-runtime-boundary',
        backendKind: 'real-shell-controller',
      ),
    );

    expect(safety.state, RuntimeActionSafetyState.captureSnapshotFirst);
    expect(safety.blocksRetry, isTrue);
    expect(safety.recommendsSnapshotFirst, isTrue);
    expect(safety.detail, contains('Preserve the current runtime evidence'));
  });

  test('connecting with stale session truth still blocks retry shortcut', () {
    final safety = RuntimeActionSafety.resolve(
      status: ClientConnectionStatus(
        phase: ClientConnectionPhase.connecting,
        message: 'Connecting current profile...',
        updatedAt: DateTime.now(),
        activeProfileId: 'sample-hk-1',
      ),
      session: ControllerRuntimeSession(
        isRunning: true,
        updatedAt: DateTime.now().subtract(const Duration(minutes: 4)),
        phase: ControllerRuntimePhase.alive,
      ),
      posture: describeRuntimePosture(
        runtimeMode: 'real-runtime-boundary',
        backendKind: 'real-shell-controller',
      ),
    );

    expect(safety.state, RuntimeActionSafetyState.captureSnapshotFirst);
    expect(safety.blocksRetry, isTrue);
    expect(safety.recommendsSnapshotFirst, isTrue);
  });
}
