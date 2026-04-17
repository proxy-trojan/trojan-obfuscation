import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/analytics/application/ux_metric_event_mapper.dart';

void main() {
  test('maps runtime-true session-ready into success event', () {
    final mapper = UxMetricEventMapper();

    final events = mapper.fromConnectionSnapshot(
      userId: 'u1',
      sessionId: 's1',
      phase: 'connected',
      runtimePosture: 'runtimeTrue',
      failureFamily: null,
    );

    expect(
      events.any((event) => event.name == 'runtime_session_ready_runtime_true'),
      isTrue,
    );
  });

  test('maps connecting phase into first connect attempted event', () {
    final mapper = UxMetricEventMapper();

    final events = mapper.fromConnectionSnapshot(
      userId: 'u1',
      sessionId: 's1',
      phase: 'connecting',
      runtimePosture: 'fallbackStub',
      failureFamily: null,
    );

    expect(
      events.any((event) => event.name == 'first_connect_attempted'),
      isTrue,
    );
  });

  test('maps error with failure family into failure and recovery events', () {
    final mapper = UxMetricEventMapper();

    final events = mapper.fromConnectionSnapshot(
      userId: 'u1',
      sessionId: 's1',
      phase: 'error',
      runtimePosture: 'fallbackStub',
      failureFamily: 'connect',
    );

    expect(
      events.any((event) => event.name == 'connect_failed_connect'),
      isTrue,
    );
    expect(
      events.any((event) => event.name == 'recovery_suggested'),
      isTrue,
    );
  });
}
