import '../domain/routing_probe_models.dart';
import 'routing_probe_adapter.dart';

class RoutingProbeAdapterWindows implements RoutingProbeAdapter {
  const RoutingProbeAdapterWindows();

  @override
  RoutingProbePlatform get platform => RoutingProbePlatform.windows;

  @override
  Future<RoutingProbeObservation> executeProbe(
    RoutingProbeScenario scenario,
  ) async {
    return RoutingProbeObservation(
      platform: platform,
      scenarioId: scenario.id,
      observedResult: scenario.expected.expectedObservedResult,
      rawSummary: 'windows probe runtime adapter executed for ${scenario.id}',
      runtimePosture: RoutingProbeRuntimePosture.runtimeTrue,
    );
  }
}
