import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/routing/testing/application/routing_probe_runner.dart';
import 'package:trojan_pro_client/features/routing/testing/application/routing_probe_scenarios.dart';
import 'package:trojan_pro_client/features/routing/testing/domain/routing_probe_models.dart';
import 'package:trojan_pro_client/features/routing/testing/platform/routing_probe_adapter.dart';

class _FallbackAdapter implements RoutingProbeAdapter {
  const _FallbackAdapter();

  @override
  RoutingProbePlatform get platform => RoutingProbePlatform.windows;

  @override
  Future<RoutingProbeObservation> executeProbe(RoutingProbeScenario scenario) async {
    return RoutingProbeObservation(
      platform: platform,
      scenarioId: scenario.id,
      observedResult: scenario.expected.expectedObservedResult,
      rawSummary: 'fallback stub observation',
      runtimePosture: RoutingProbeRuntimePosture.fallbackStub,
    );
  }
}

void main() {
  test('mini smoke fails when dataplane posture is not runtime-true', () async {
    const runner = RoutingProbeRunner(
      adapters: <RoutingProbeAdapter>[_FallbackAdapter()],
    );

    final result =
        await runner.runMiniSmoke(routingProbeCoreScenarios.take(1).toList());

    expect(result.passed, isFalse);
    expect(result.reason, contains('runtime-true'));
  });
}
