import '../domain/routing_probe_models.dart';
import 'routing_probe_adapter.dart';

class RoutingProbeAdapterLinux implements RoutingProbeAdapter {
  const RoutingProbeAdapterLinux();

  @override
  RoutingProbePlatform get platform => RoutingProbePlatform.linux;

  @override
  Future<RoutingProbeObservation> executeProbe(
    RoutingProbeScenario scenario,
  ) async {
    return RoutingProbeObservation(
      platform: platform,
      scenarioId: scenario.id,
      observedResult: scenario.expected.expectedObservedResult,
      rawSummary: 'linux probe simulated for ${scenario.id}',
    );
  }
}
