import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/routing/testing/application/routing_probe_verdict_service.dart';
import 'package:trojan_pro_client/features/routing/testing/domain/routing_probe_models.dart';

void main() {
  test('decision mismatch should fail case verdict', () {
    const service = RoutingProbeVerdictService();
    final evidence = RoutingProbeEvidenceRecord(
      scenarioId: 'case-1',
      platform: RoutingProbePlatform.linux,
      phase: RoutingProbePhase.decision,
      decisionAction: RoutingProbeAction.proxy,
      observedResult: RoutingProbeObservedResult.proxy,
      errorType: RoutingProbeErrorType.decisionMismatch,
      errorDetail: 'expected=direct actual=proxy',
      fallbackApplied: false,
      timestamp: DateTime.now(),
    );

    final verdict = service.evaluateSingle(evidence);
    expect(verdict.status, RoutingProbeVerdictStatus.fail);
  });

  test('platform capability gap should produce not_applicable', () {
    const service = RoutingProbeVerdictService();
    final evidence = RoutingProbeEvidenceRecord(
      scenarioId: 'case-2',
      platform: RoutingProbePlatform.macos,
      phase: RoutingProbePhase.probe,
      decisionAction: RoutingProbeAction.direct,
      observedResult: RoutingProbeObservedResult.unknown,
      errorType: RoutingProbeErrorType.platformCapabilityGap,
      errorDetail: 'processPath probe unsupported',
      fallbackApplied: false,
      timestamp: DateTime.now(),
    );

    final verdict = service.evaluateSingle(evidence);
    expect(verdict.status, RoutingProbeVerdictStatus.notApplicable);
  });
}
