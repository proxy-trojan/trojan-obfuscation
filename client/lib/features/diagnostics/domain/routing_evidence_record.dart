class RoutingEvidenceRecord {
  const RoutingEvidenceRecord({
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
  final String platform;
  final String phase;
  final String decisionAction;
  final String observedResult;
  final String errorType;
  final String errorDetail;
  final bool fallbackApplied;
  final DateTime timestamp;
  final String? matchedRuleId;
  final String? policyGroupId;
  final String? explain;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'scenarioId': scenarioId,
      'platform': platform,
      'phase': phase,
      'decisionAction': decisionAction,
      'observedResult': observedResult,
      'errorType': errorType,
      'errorDetail': errorDetail,
      'fallbackApplied': fallbackApplied,
      'timestamp': timestamp.toIso8601String(),
      'matchedRuleId': matchedRuleId,
      'policyGroupId': policyGroupId,
      'explain': explain,
    };
  }
}
