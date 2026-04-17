import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/routing/testing/domain/routing_probe_models.dart';

void main() {
  test('probe scenario carries expectation and metadata fingerprint', () {
    const scenario = RoutingProbeScenario(
      id: 'case-rule-direct',
      host: 'api.example.com',
      port: 443,
      protocol: 'tcp',
      expected: RoutingProbeExpectation(
        expectedAction: RoutingProbeAction.direct,
        expectedObservedResult: RoutingProbeObservedResult.direct,
      ),
    );

    expect(scenario.id, 'case-rule-direct');
    expect(scenario.expected.expectedAction, RoutingProbeAction.direct);
  });

  test('evidence record includes error type and fallback flag', () {
    final record = RoutingProbeEvidenceRecord(
      scenarioId: 'case-fallback',
      platform: RoutingProbePlatform.linux,
      phase: RoutingProbePhase.decision,
      decisionAction: RoutingProbeAction.proxy,
      observedResult: RoutingProbeObservedResult.direct,
      errorType: RoutingProbeErrorType.observationMismatch,
      errorDetail: 'decision=proxy observed=direct',
      fallbackApplied: true,
      runtimePosture: RoutingProbeRuntimePosture.fallbackStub,
      timestamp: DateTime.parse('2026-04-16T00:00:00.000Z'),
    );

    expect(record.errorType, RoutingProbeErrorType.observationMismatch);
    expect(record.fallbackApplied, isTrue);
  });
}
