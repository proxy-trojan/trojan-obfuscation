import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/routing/testing/domain/routing_probe_models.dart';

void main() {
  test('runtime posture marks real adapter as runtime-true', () {
    final record = RoutingProbeEvidenceRecord(
      scenarioId: 'rule-direct',
      platform: RoutingProbePlatform.linux,
      phase: RoutingProbePhase.observe,
      decisionAction: RoutingProbeAction.direct,
      observedResult: RoutingProbeObservedResult.direct,
      errorType: RoutingProbeErrorType.none,
      errorDetail: '',
      fallbackApplied: false,
      runtimePosture: RoutingProbeRuntimePosture.runtimeTrue,
      timestamp: DateTime.now(),
    );

    expect(record.runtimePosture, RoutingProbeRuntimePosture.runtimeTrue);
    expect(record.isRuntimeTrueDataplane, isTrue);
  });

  test('fallback posture is not runtime-true dataplane evidence', () {
    final record = RoutingProbeEvidenceRecord(
      scenarioId: 'rule-proxy',
      platform: RoutingProbePlatform.windows,
      phase: RoutingProbePhase.observe,
      decisionAction: RoutingProbeAction.proxy,
      observedResult: RoutingProbeObservedResult.proxy,
      errorType: RoutingProbeErrorType.none,
      errorDetail: '',
      fallbackApplied: true,
      runtimePosture: RoutingProbeRuntimePosture.fallbackStub,
      timestamp: DateTime.now(),
    );

    expect(record.runtimePosture, RoutingProbeRuntimePosture.fallbackStub);
    expect(record.isRuntimeTrueDataplane, isFalse);
  });
}
