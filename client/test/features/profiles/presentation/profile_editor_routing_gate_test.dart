import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/profiles/domain/client_profile.dart';
import 'package:trojan_pro_client/features/routing/application/routing_dry_run_service.dart';
import 'package:trojan_pro_client/features/routing/application/routing_guardrail_service.dart';
import 'package:trojan_pro_client/features/routing/domain/routing_change_gate.dart';
import 'package:trojan_pro_client/features/routing/domain/routing_models.dart';
import 'package:trojan_pro_client/features/routing/domain/routing_profile_config.dart';
import 'package:trojan_pro_client/features/routing/testing/application/routing_probe_scenarios.dart';

void main() {
  test('guardrail blocks config when policy group reference is missing', () {
    const candidate = RoutingProfileConfig(
      mode: RoutingMode.rule,
      defaultAction: RoutingAction.proxy,
      globalAction: RoutingAction.proxy,
      policyGroups: <RoutingPolicyGroup>[],
      rules: <RoutingRule>[
        RoutingRule(
          id: 'rule-missing-policy-ref',
          name: 'missing policy ref',
          enabled: true,
          priority: 1,
          match: RoutingRuleMatch(domainKeyword: 'blocked.example'),
          action: RoutingRuleAction.policyGroup('group-not-found'),
        ),
      ],
    );

    const guardrail = RoutingGuardrailService();
    final report = guardrail.evaluate(candidate);

    expect(report.applyDisposition, RoutingApplyDisposition.blocked);
    expect(report.level, RoutingRiskLevel.high);
    expect(
      report.issues.any((issue) => issue.code == 'MISSING_POLICY_GROUP'),
      isTrue,
    );
  });

  test('guardrail warning + dry-run diff form confirmation payload baseline', () {
    const baseline = RoutingProfileConfig.defaults;
    const candidate = RoutingProfileConfig(
      mode: RoutingMode.rule,
      defaultAction: RoutingAction.proxy,
      globalAction: RoutingAction.proxy,
      policyGroups: <RoutingPolicyGroup>[
        RoutingPolicyGroup(
          id: 'group-safe',
          name: 'Safe group',
          action: RoutingAction.proxy,
        ),
      ],
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

    const guardrail = RoutingGuardrailService();
    const dryRun = RoutingDryRunService();

    final report = guardrail.evaluate(candidate);
    final diff = dryRun.compare(
      before: baseline,
      after: candidate,
      scenarios: routingProbeCoreScenarios,
    );

    expect(report.applyDisposition, RoutingApplyDisposition.requiresConfirm);
    expect(report.level, RoutingRiskLevel.medium);
    expect(report.issues.any((issue) => issue.code == 'WIDE_DIRECT_MATCH'), isTrue);

    expect(diff.changedCases, isNotEmpty);
    expect(diff.changedCases.any((changed) => changed.scenarioId == 'rule-direct'),
        isTrue);
  });

  test('submission candidate keeps user-entered routing rules intact', () {
    const candidateRouting = RoutingProfileConfig(
      mode: RoutingMode.rule,
      defaultAction: RoutingAction.proxy,
      globalAction: RoutingAction.proxy,
      policyGroups: <RoutingPolicyGroup>[],
      rules: <RoutingRule>[
        RoutingRule(
          id: 'rule-missing-policy-ref',
          name: 'missing policy ref',
          enabled: true,
          priority: 1,
          match: RoutingRuleMatch(domainKeyword: 'blocked.example'),
          action: RoutingRuleAction.policyGroup('group-not-found'),
        ),
      ],
    );

    final profile = ClientProfile(
      id: 'profile-1',
      name: 'Blocked Profile',
      serverHost: 'blocked.example.com',
      serverPort: 443,
      sni: 'blocked.example.com',
      localSocksPort: 1080,
      verifyTls: true,
      updatedAt: DateTime.parse('2026-04-16T00:00:00.000Z'),
      routing: candidateRouting,
    );

    expect(profile.routing.rules.single.action.usesPolicyGroup, isTrue);
    expect(profile.routing.rules.single.action.policyGroupId, 'group-not-found');
  });
}
