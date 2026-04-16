import '../domain/routing_probe_models.dart';

abstract interface class RoutingProbeAdapter {
  RoutingProbePlatform get platform;

  Future<RoutingProbeObservation> executeProbe(RoutingProbeScenario scenario);
}

class RoutingProbeObservation {
  const RoutingProbeObservation({
    required this.platform,
    required this.scenarioId,
    required this.observedResult,
    required this.rawSummary,
  });

  final RoutingProbePlatform platform;
  final String scenarioId;
  final RoutingProbeObservedResult observedResult;
  final String rawSummary;
}
