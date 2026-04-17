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
        final runtimeTrue =
            observation.runtimePosture == RoutingProbeRuntimePosture.runtimeTrue;
        output.add(
          RoutingProbeEvidenceRecord(
            scenarioId: scenario.id,
            platform: observation.platform,
            phase: RoutingProbePhase.observe,
            decisionAction: scenario.expected.expectedAction,
            observedResult: observation.observedResult,
            errorType: runtimeTrue
                ? RoutingProbeErrorType.none
                : RoutingProbeErrorType.platformCapabilityGap,
            errorDetail: runtimeTrue
                ? ''
                : 'dataplane evidence is not runtime-true on ${observation.platform.name}',
            fallbackApplied: !runtimeTrue,
            runtimePosture: observation.runtimePosture,
            timestamp: DateTime.now(),
            explain: observation.rawSummary,
          ),
        );
      }
    }

    return output;
  }

  Future<RoutingMiniSmokeResult> runMiniSmoke(
    List<RoutingProbeScenario> scenarios,
  ) async {
    final evidence = await runBatch(scenarios);
    var passed = true;
    String reason = 'Mini smoke passed for all routing scenarios.';

    for (final record in evidence) {
      if (!record.isRuntimeTrueDataplane) {
        passed = false;
        reason =
            'Mini smoke failed for ${record.scenarioId} on ${record.platform.name}: dataplane evidence is not runtime-true (${record.runtimePosture.name}).';
        break;
      }

      if (!_matchesExpectation(record)) {
        passed = false;
        reason =
            'Mini smoke failed for ${record.scenarioId} on ${record.platform.name}: expected ${record.decisionAction.name}, observed ${record.observedResult.name}.';
        break;
      }
    }

    return RoutingMiniSmokeResult(
      passed: passed,
      reason: reason,
      evidence: evidence,
    );
  }

  bool _matchesExpectation(RoutingProbeEvidenceRecord record) {
    final expected = record.decisionAction;
    final observed = record.observedResult;

    return switch (expected) {
      RoutingProbeAction.direct => observed == RoutingProbeObservedResult.direct,
      RoutingProbeAction.proxy => observed == RoutingProbeObservedResult.proxy,
      RoutingProbeAction.block =>
        observed == RoutingProbeObservedResult.blocked,
    };
  }
}

class RoutingMiniSmokeResult {
  const RoutingMiniSmokeResult({
    required this.passed,
    required this.reason,
    required this.evidence,
  });

  final bool passed;
  final String reason;
  final List<RoutingProbeEvidenceRecord> evidence;
}
