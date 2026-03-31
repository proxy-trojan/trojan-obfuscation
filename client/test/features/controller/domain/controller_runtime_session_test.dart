import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/controller/domain/controller_runtime_session.dart';

void main() {
  test('marks recently refreshed running session as live', () {
    final session = ControllerRuntimeSession(
      isRunning: true,
      updatedAt: DateTime.now().subtract(const Duration(seconds: 5)),
      phase: ControllerRuntimePhase.sessionReady,
      expectedLocalSocksPort: 10808,
    );

    expect(session.truth, ControllerRuntimeSessionTruth.live);
    expect(session.truth.label, 'Live');
  });

  test('marks older running session as stale', () {
    final session = ControllerRuntimeSession(
      isRunning: true,
      updatedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      phase: ControllerRuntimePhase.sessionReady,
      expectedLocalSocksPort: 10808,
    );

    expect(session.truth, ControllerRuntimeSessionTruth.stale);
    expect(session.truthNote, contains('stale'));
  });

  test('marks non-running non-stopped session as residual snapshot', () {
    final session = ControllerRuntimeSession(
      isRunning: false,
      updatedAt: DateTime.now().subtract(const Duration(minutes: 1)),
      phase: ControllerRuntimePhase.sessionReady,
      expectedLocalSocksPort: 10808,
    );

    expect(session.truth, ControllerRuntimeSessionTruth.residual);
    expect(session.truth.label, 'Residual snapshot');
  });

  test('marks stop-requested session as stopping', () {
    final session = ControllerRuntimeSession(
      isRunning: true,
      updatedAt: DateTime.now().subtract(const Duration(seconds: 20)),
      phase: ControllerRuntimePhase.alive,
      stopRequested: true,
      stopRequestedAt: DateTime.now().subtract(const Duration(seconds: 10)),
      expectedLocalSocksPort: 10808,
    );

    expect(session.truth, ControllerRuntimeSessionTruth.stopping);
    expect(session.truthNote, contains('stop request'));
    expect(session.needsAttention, isTrue);
    expect(session.recoveryGuidance, contains('exit confirmation'));
  });

  test('does not mark live session as needing attention', () {
    final session = ControllerRuntimeSession(
      isRunning: true,
      updatedAt: DateTime.now().subtract(const Duration(seconds: 3)),
      phase: ControllerRuntimePhase.sessionReady,
      expectedLocalSocksPort: 10808,
    );

    expect(session.truth, ControllerRuntimeSessionTruth.live);
    expect(session.needsAttention, isFalse);
    expect(session.recoveryGuidance, contains('No recovery action'));
  });

  test('gives recovery guidance for residual snapshot state', () {
    final session = ControllerRuntimeSession(
      isRunning: false,
      updatedAt: DateTime.now().subtract(const Duration(minutes: 1)),
      phase: ControllerRuntimePhase.sessionReady,
      expectedLocalSocksPort: 10808,
    );

    expect(session.truth, ControllerRuntimeSessionTruth.residual);
    expect(session.needsAttention, isTrue);
    expect(session.recoveryGuidance, contains('retry from Profiles'));
  });
}
