import '../domain/routing_change_gate.dart';
import '../domain/routing_models.dart';
import '../domain/routing_profile_config.dart';

class RoutingGuardrailService {
  const RoutingGuardrailService();

  RoutingGuardrailReport evaluate(RoutingProfileConfig config) {
    final issues = <RoutingGuardrailIssue>[];

    final policyIds = config.policyGroups.map((group) => group.id).toSet();
    for (final rule in config.rules.where((rule) => rule.enabled)) {
      if (rule.action.usesPolicyGroup &&
          !policyIds.contains(rule.action.policyGroupId)) {
        issues.add(
          RoutingGuardrailIssue(
            code: 'MISSING_POLICY_GROUP',
            message:
                'Rule "${rule.id}" references a missing policy group and cannot be applied safely.',
            blocking: true,
            ruleId: rule.id,
          ),
        );
      }

      final keyword = (rule.match.domainKeyword ?? '').trim().toLowerCase();
      final directAction = rule.action.directAction;
      final isWideKeyword = keyword == 'com' || keyword == 'net' || keyword == 'org';
      if (directAction == RoutingAction.direct && isWideKeyword) {
        issues.add(
          RoutingGuardrailIssue(
            code: 'WIDE_DIRECT_MATCH',
            message:
                'Rule "${rule.id}" uses wide direct keyword "$keyword" and may bypass proxy unexpectedly.',
            blocking: false,
            ruleId: rule.id,
          ),
        );
      }
    }

    final hasBlockingIssue = issues.any((issue) => issue.blocking);
    if (hasBlockingIssue) {
      return RoutingGuardrailReport(
        level: RoutingRiskLevel.high,
        applyDisposition: RoutingApplyDisposition.blocked,
        issues: issues,
      );
    }

    if (issues.isNotEmpty) {
      return RoutingGuardrailReport(
        level: RoutingRiskLevel.medium,
        applyDisposition: RoutingApplyDisposition.requiresConfirm,
        issues: issues,
      );
    }

    return const RoutingGuardrailReport(
      level: RoutingRiskLevel.low,
      applyDisposition: RoutingApplyDisposition.allowed,
      issues: <RoutingGuardrailIssue>[],
    );
  }
}
