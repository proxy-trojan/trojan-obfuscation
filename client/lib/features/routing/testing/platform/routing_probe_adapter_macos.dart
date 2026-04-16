import '../domain/routing_probe_models.dart';
import 'routing_probe_adapter.dart';

class RoutingProbeAdapterMacos implements RoutingProbeAdapter {
  const RoutingProbeAdapterMacos();

  @override
  RoutingProbePlatform get platform => RoutingProbePlatform.macos;

  @override
  Future<RoutingProbeObservation> executeProbe(
    RoutingProbeScenario scenario,
  ) async {
    return RoutingProbeObservation(
      platform: platform,
      scenarioId: scenario.id,
      observedResult: scenario.expected.expectedObservedResult,
      rawSummary: 'macos probe simulated for ${scenario.id}',
    );
  }
}
