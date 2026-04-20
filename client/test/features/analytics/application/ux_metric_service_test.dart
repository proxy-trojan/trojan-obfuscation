import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/analytics/application/ux_metric_service.dart';
import 'package:trojan_pro_client/features/analytics/domain/ux_metric_models.dart';

void main() {
  test('FCSR counts runtime-true ready as success and excludes fallback', () {
    final service = UxMetricService();
    final events = <UxEvent>[
      UxEvent(
        userId: 'u1',
        name: 'first_session_started',
        at: DateTime.parse('2026-04-17T10:00:00Z'),
      ),
      UxEvent(
        userId: 'u1',
        name: 'runtime_session_ready_runtime_true',
        at: DateTime.parse('2026-04-17T10:05:00Z'),
      ),
      UxEvent(
        userId: 'u2',
        name: 'first_session_started',
        at: DateTime.parse('2026-04-17T10:00:00Z'),
      ),
      UxEvent(
        userId: 'u2',
        name: 'runtime_session_ready_fallback',
        at: DateTime.parse('2026-04-17T10:05:00Z'),
      ),
    ];

    final result = service.computeFcsr(events);

    expect(result.numerator, 1);
    expect(result.denominator, 2);
    expect(result.value, 0.5);
  });

  test('HFE combines action time, steps and rework into index', () {
    final service = UxMetricService();
    final events = <UxEvent>[
      UxEvent(
        userId: 'u1',
        sessionId: 's1',
        name: 'quick_connect_clicked',
        at: DateTime.parse('2026-04-17T10:00:00Z'),
      ),
      UxEvent(
        userId: 'u1',
        sessionId: 's1',
        name: 'action_completed',
        at: DateTime.parse('2026-04-17T10:00:04Z'),
        fields: const <String, Object?>{
          'actionType': 'connect',
          'interactionSteps': 2,
        },
      ),
      UxEvent(
        userId: 'u1',
        sessionId: 's1',
        name: 'action_rework_detected',
        at: DateTime.parse('2026-04-17T10:00:05Z'),
      ),
      UxEvent(
        userId: 'u2',
        sessionId: 's2',
        name: 'quick_disconnect_clicked',
        at: DateTime.parse('2026-04-17T10:10:00Z'),
      ),
      UxEvent(
        userId: 'u2',
        sessionId: 's2',
        name: 'action_completed',
        at: DateTime.parse('2026-04-17T10:10:08Z'),
        fields: const <String, Object?>{
          'actionType': 'disconnect',
          'interactionSteps': 4,
        },
      ),
    ];

    final result = service.computeHfe(events);

    expect(result.tActionSeconds, 6.0);
    expect(result.nSteps, 3.0);
    expect(result.rRework, 0.5);
    expect(result.index, closeTo(0.575, 1e-9));
  });

  test('SSR counts recovery succeeded over suggested sessions', () {
    final service = UxMetricService();
    final events = <UxEvent>[
      UxEvent(
        userId: 'u1',
        sessionId: 's1',
        name: 'recovery_suggested',
        at: DateTime.parse('2026-04-17T10:00:00Z'),
      ),
      UxEvent(
        userId: 'u1',
        sessionId: 's1',
        name: 'recovery_succeeded',
        at: DateTime.parse('2026-04-17T10:01:00Z'),
      ),
      UxEvent(
        userId: 'u2',
        sessionId: 's2',
        name: 'recovery_suggested',
        at: DateTime.parse('2026-04-17T10:05:00Z'),
      ),
    ];

    final result = service.computeSsr(events);

    expect(result.numerator, 1);
    expect(result.denominator, 2);
    expect(result.value, 0.5);
  });

  test('STE requires posture + recovery evidence fields in export completion', () {
    final service = UxMetricService();
    final events = <UxEvent>[
      UxEvent(
        userId: 'u1',
        sessionId: 's1',
        name: 'diagnostics_export_completed',
        at: DateTime.parse('2026-04-17T10:00:00Z'),
        fields: const <String, Object?>{
          'runtimePosture': 'runtime_true',
          'includesRecoveryEvidence': true,
        },
      ),
      UxEvent(
        userId: 'u2',
        sessionId: 's2',
        name: 'diagnostics_export_completed',
        at: DateTime.parse('2026-04-17T10:10:00Z'),
        fields: const <String, Object?>{
          'runtimePosture': 'fallback',
        },
      ),
    ];

    final result = service.computeSte(events);

    expect(result.numerator, 1);
    expect(result.denominator, 2);
    expect(result.value, 0.5);
  });
}
