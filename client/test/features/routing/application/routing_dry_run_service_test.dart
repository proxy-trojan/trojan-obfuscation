import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/routing/application/routing_dry_run_service.dart';
import 'package:trojan_pro_client/features/routing/domain/routing_models.dart';
import 'package:trojan_pro_client/features/routing/domain/routing_profile_config.dart';
import 'package:trojan_pro_client/features/routing/testing/application/routing_probe_scenarios.dart';

void main() {
  const service = RoutingDryRunService();

  test('dry-run should report impacted scenarios when action changes', () {
    const before = RoutingProfileConfig.defaults;
    const after = RoutingProfileConfig(
      mode: RoutingMode.rule,
      defaultAction: RoutingAction.proxy,
      globalAction: RoutingAction.proxy,
      policyGroups: <RoutingPolicyGroup>[],
      rules: <RoutingRule>[
        RoutingRule(
          id: 'rule-direct-example',
          name: 'direct example',
          enabled: true,
          priority: 1,
          match: RoutingRuleMatch(domainKeyword: 'direct.example'),
          action: RoutingRuleAction.direct(RoutingAction.direct),
        ),
      ],
    );

    final report = service.compare(
      before: before,
      after: after,
      scenarios: routingProbeCoreScenarios,
    );

    expect(report.changedCases, isNotEmpty);
    expect(
      report.changedCases.any((changed) => changed.scenarioId == 'rule-direct'),
      isTrue,
    );
    final directCase = report.changedCases.firstWhere(
      (changed) => changed.scenarioId == 'rule-direct',
    );
    expect(directCase.beforeAction, RoutingAction.proxy);
    expect(directCase.afterAction, RoutingAction.direct);
  });

  test('dry-run should include rule change even when action remains unchanged', () {
    const before = RoutingProfileConfig(
      mode: RoutingMode.rule,
      defaultAction: RoutingAction.proxy,
      globalAction: RoutingAction.proxy,
      policyGroups: <RoutingPolicyGroup>[],
      rules: <RoutingRule>[
        RoutingRule(
          id: 'rule-proxy-old',
          name: 'old proxy rule',
          enabled: true,
          priority: 10,
          match: RoutingRuleMatch(domainKeyword: 'proxy.example'),
          action: RoutingRuleAction.direct(RoutingAction.proxy),
        ),
      ],
    );

    const after = RoutingProfileConfig(
      mode: RoutingMode.rule,
      defaultAction: RoutingAction.proxy,
      globalAction: RoutingAction.proxy,
      policyGroups: <RoutingPolicyGroup>[],
      rules: <RoutingRule>[
        RoutingRule(
          id: 'rule-proxy-new',
          name: 'new proxy rule',
          enabled: true,
          priority: 10,
          match: RoutingRuleMatch(domainKeyword: 'proxy.example'),
          action: RoutingRuleAction.direct(RoutingAction.proxy),
        ),
      ],
    );

    final report = service.compare(
      before: before,
      after: after,
      scenarios: routingProbeCoreScenarios,
    );

    final proxyCase = report.changedCases.firstWhere(
      (changed) => changed.scenarioId == 'rule-proxy',
    );
    expect(proxyCase.beforeAction, RoutingAction.proxy);
    expect(proxyCase.afterAction, RoutingAction.proxy);
    expect(proxyCase.beforeMatchedRuleId, 'rule-proxy-old');
    expect(proxyCase.afterMatchedRuleId, 'rule-proxy-new');
  });
}
