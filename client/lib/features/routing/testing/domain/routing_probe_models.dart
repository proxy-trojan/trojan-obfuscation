enum RoutingProbePlatform { linux, windows, macos }

enum RoutingProbeAction { proxy, direct, block }

enum RoutingProbeObservedResult { proxy, direct, blocked, unknown }

enum RoutingProbePhase { connect, probe, decision, observe, export }

enum RoutingProbeErrorType {
  none,
  controllerFailure,
  probeExecutionFailure,
  decisionMismatch,
  observationMismatch,
  platformCapabilityGap,
  exportFailure,
}

class RoutingProbeExpectation {
  const RoutingProbeExpectation({
    required this.expectedAction,
    required this.expectedObservedResult,
  });

  final RoutingProbeAction expectedAction;
  final RoutingProbeObservedResult expectedObservedResult;
}

class RoutingProbeScenario {
  const RoutingProbeScenario({
    required this.id,
    required this.host,
    required this.port,
    required this.protocol,
    required this.expected,
  });

  final String id;
  final String host;
  final int port;
  final String protocol;
  final RoutingProbeExpectation expected;
}

class RoutingProbeEvidenceRecord {
  const RoutingProbeEvidenceRecord({
    required this.scenarioId,
    required this.platform,
    required this.phase,
    required this.decisionAction,
    required this.observedResult,
    required this.errorType,
    required this.errorDetail,
    required this.fallbackApplied,
    required this.timestamp,
    this.matchedRuleId,
    this.policyGroupId,
    this.explain,
  });

  final String scenarioId;
  final RoutingProbePlatform platform;
  final RoutingProbePhase phase;
  final RoutingProbeAction decisionAction;
  final RoutingProbeObservedResult observedResult;
  final RoutingProbeErrorType errorType;
  final String errorDetail;
  final bool fallbackApplied;
  final DateTime timestamp;
  final String? matchedRuleId;
  final String? policyGroupId;
  final String? explain;
}
