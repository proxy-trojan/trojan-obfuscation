import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/routing/application/routing_guardrail_service.dart';
import 'package:trojan_pro_client/features/routing/domain/routing_change_gate.dart';
import 'package:trojan_pro_client/features/routing/domain/routing_models.dart';
import 'package:trojan_pro_client/features/routing/domain/routing_profile_config.dart';

void main() {
  const service = RoutingGuardrailService();

  test('missing policy group reference should hard-block apply', () {
    const candidate = RoutingProfileConfig(
      mode: RoutingMode.rule,
      defaultAction: RoutingAction.proxy,
      globalAction: RoutingAction.proxy,
      policyGroups: <RoutingPolicyGroup>[],
      rules: <RoutingRule>[
        RoutingRule(
          id: 'rule-1',
          name: 'policy-ref',
          enabled: true,
          priority: 1,
          match: RoutingRuleMatch(domainKeyword: 'example'),
          action: RoutingRuleAction.policyGroup('missing-group'),
        ),
      ],
    );

    final report = service.evaluate(candidate);

    expect(report.level, RoutingRiskLevel.high);
    expect(report.applyDisposition, RoutingApplyDisposition.blocked);
    expect(
      report.issues.any((issue) => issue.code == 'MISSING_POLICY_GROUP'),
      isTrue,
    );
  });

  test('wide direct keyword should produce soft warning only', () {
    const candidate = RoutingProfileConfig(
      mode: RoutingMode.rule,
      defaultAction: RoutingAction.proxy,
      globalAction: RoutingAction.proxy,
      policyGroups: <RoutingPolicyGroup>[],
      rules: <RoutingRule>[
        RoutingRule(
          id: 'rule-wide-direct',
          name: 'wide direct',
          enabled: true,
          priority: 1,
          match: RoutingRuleMatch(domainKeyword: 'com'),
          action: RoutingRuleAction.direct(RoutingAction.direct),
        ),
      ],
    );

    final report = service.evaluate(candidate);

    expect(report.level, RoutingRiskLevel.medium);
    expect(report.applyDisposition, RoutingApplyDisposition.requiresConfirm);
    expect(
      report.issues.any((issue) => issue.code == 'WIDE_DIRECT_MATCH'),
      isTrue,
    );
  });

  test('clean config should be allowed without issues', () {
    const candidate = RoutingProfileConfig(
      mode: RoutingMode.rule,
      defaultAction: RoutingAction.proxy,
      globalAction: RoutingAction.proxy,
      policyGroups: <RoutingPolicyGroup>[
        RoutingPolicyGroup(
          id: 'group-proxy',
          name: 'Proxy Group',
          action: RoutingAction.proxy,
        ),
      ],
      rules: <RoutingRule>[
        RoutingRule(
          id: 'rule-safe',
          name: 'safe',
          enabled: true,
          priority: 1,
          match: RoutingRuleMatch(domainKeyword: 'secure.example'),
          action: RoutingRuleAction.policyGroup('group-proxy'),
        ),
      ],
    );

    final report = service.evaluate(candidate);

    expect(report.level, RoutingRiskLevel.low);
    expect(report.applyDisposition, RoutingApplyDisposition.allowed);
    expect(report.issues, isEmpty);
  });
}
