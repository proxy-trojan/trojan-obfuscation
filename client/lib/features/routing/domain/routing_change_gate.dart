enum RoutingRiskLevel {
  low,
  medium,
  high,
}

enum RoutingApplyDisposition {
  allowed,
  requiresConfirm,
  blocked,
}

class RoutingGuardrailIssue {
  const RoutingGuardrailIssue({
    required this.code,
    required this.message,
    required this.blocking,
    this.ruleId,
  });

  final String code;
  final String message;
  final bool blocking;
  final String? ruleId;
}

class RoutingGuardrailReport {
  const RoutingGuardrailReport({
    required this.level,
    required this.applyDisposition,
    required this.issues,
  });

  final RoutingRiskLevel level;
  final RoutingApplyDisposition applyDisposition;
  final List<RoutingGuardrailIssue> issues;
}
