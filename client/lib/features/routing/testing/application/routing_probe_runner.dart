import '../domain/routing_probe_models.dart';
import '../platform/routing_probe_adapter.dart';

class RoutingProbeRunner {
  const RoutingProbeRunner({required this.adapters});

  final List<RoutingProbeAdapter> adapters;

  Future<List<RoutingProbeEvidenceRecord>> runBatch(
    List<RoutingProbeScenario> scenarios,
  ) async {
    final output = <RoutingProbeEvidenceRecord>[];

    for (final adapter in adapters) {
      for (final scenario in scenarios) {
        final observation = await adapter.executeProbe(scenario);
        output.add(
          RoutingProbeEvidenceRecord(
            scenarioId: scenario.id,
            platform: observation.platform,
            phase: RoutingProbePhase.observe,
            decisionAction: scenario.expected.expectedAction,
            observedResult: observation.observedResult,
            errorType: RoutingProbeErrorType.none,
            errorDetail: '',
            fallbackApplied: false,
            timestamp: DateTime.now(),
            explain: observation.rawSummary,
          ),
        );
      }
    }

    return output;
  }
}
