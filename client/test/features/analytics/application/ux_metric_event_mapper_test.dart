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

  test('maps recovery action executed event with action/source/family/posture', () {
    final mapper = UxMetricEventMapper();

    final event = mapper.recoveryActionExecuted(
      userId: 'u1',
      sessionId: 's1',
      action: 'open_troubleshooting',
      source: 'readiness_recommendation',
      failureFamily: 'connect',
      runtimePosture: 'runtime_true',
      at: DateTime.parse('2026-04-21T00:00:00Z'),
    );

    expect(event.name, 'recovery_action_executed');
    expect(event.fields['action'], 'open_troubleshooting');
    expect(event.fields['source'], 'readiness_recommendation');
    expect(event.fields['failureFamily'], 'connect');
    expect(event.fields['runtimePosture'], 'runtime_true');
  });

  test('maps recovery outcome event for success/fail/abandon', () {
    final mapper = UxMetricEventMapper();

    final success = mapper.recoveryOutcome(
      userId: 'u1',
      sessionId: 's1',
      action: 'retry_connect',
      source: 'readiness_recommendation',
      failureFamily: 'connect',
      runtimePosture: 'runtime_true',
      outcome: 'success',
      at: DateTime.parse('2026-04-21T00:01:00Z'),
    );
    final fail = mapper.recoveryOutcome(
      userId: 'u1',
      sessionId: 's1',
      action: 'retry_connect',
      source: 'readiness_recommendation',
      failureFamily: 'connect',
      runtimePosture: 'runtime_true',
      outcome: 'fail',
      at: DateTime.parse('2026-04-21T00:02:00Z'),
    );
    final abandon = mapper.recoveryOutcome(
      userId: 'u1',
      sessionId: 's1',
      action: 'retry_connect',
      source: 'readiness_recommendation',
      failureFamily: 'connect',
      runtimePosture: 'runtime_true',
      outcome: 'abandon',
      at: DateTime.parse('2026-04-21T00:03:00Z'),
    );

    expect(success.name, 'recovery_outcome');
    expect(success.fields['outcome'], 'success');
    expect(fail.fields['outcome'], 'fail');
    expect(abandon.fields['outcome'], 'abandon');
  });
}
