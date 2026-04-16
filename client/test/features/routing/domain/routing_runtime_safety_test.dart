import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/routing/domain/routing_runtime_safety.dart';

void main() {
  test('two rollbacks in 30 minutes should mark candidate quarantined', () {
    final tracker = RoutingRollbackWindowTracker(
      maxRollbacks: 2,
      window: const Duration(minutes: 30),
    );

    final t0 = DateTime.parse('2026-04-16T09:00:00.000Z');
    expect(tracker.recordFailure(candidateKey: 'profile-a', at: t0), isFalse);
    expect(
      tracker.recordFailure(
        candidateKey: 'profile-a',
        at: t0.add(const Duration(minutes: 5)),
      ),
      isTrue,
    );
  });

  test('rollback records outside window should not trigger quarantine', () {
    final tracker = RoutingRollbackWindowTracker(
      maxRollbacks: 2,
      window: const Duration(minutes: 30),
    );

    final t0 = DateTime.parse('2026-04-16T09:00:00.000Z');
    expect(tracker.recordFailure(candidateKey: 'profile-a', at: t0), isFalse);
    expect(
      tracker.recordFailure(
        candidateKey: 'profile-a',
        at: t0.add(const Duration(minutes: 31)),
      ),
      isFalse,
    );
  });

  test('quarantine registry tracks and releases candidate keys', () {
    final registry = RoutingQuarantineRegistry();

    expect(registry.isQuarantined('profile-a'), isFalse);
    registry.quarantine('profile-a');
    expect(registry.isQuarantined('profile-a'), isTrue);

    registry.release('profile-a');
    expect(registry.isQuarantined('profile-a'), isFalse);
  });
}
