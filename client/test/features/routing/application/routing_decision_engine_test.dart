import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/routing/application/routing_decision_engine.dart';
import 'package:trojan_pro_client/features/routing/domain/routing_models.dart';

RoutingRule _rule({
  required String id,
  required int priority,
  required RoutingRuleMatch match,
  required RoutingRuleAction action,
  bool enabled = true,
  String name = 'rule',
}) {
  return RoutingRule(
    id: id,
    name: name,
    enabled: enabled,
    priority: priority,
    match: match,
    action: action,
  );
}

void main() {
  const engine = RoutingDecisionEngine();

  test('matches exact domain rule and returns deterministic explanation', () {
    final profile = RoutingProfile(
      id: 'routing-1',
      name: 'Default Routing',
      mode: RoutingMode.rule,
      defaultAction: RoutingAction.proxy,
      globalAction: RoutingAction.proxy,
      policyGroups: const <RoutingPolicyGroup>[],
      rules: <RoutingRule>[
        _rule(
          id: 'rule-domain-block',
          priority: 10,
          match: const RoutingRuleMatch(domainExact: 'example.com'),
          action: const RoutingRuleAction.direct(RoutingAction.block),
        ),
      ],
      updatedAt: DateTime.parse('2026-04-15T00:00:00.000Z'),
    );

    final decision = engine.resolve(
      profile: profile,
      request: const RoutingRequestMetadata(
        host: 'Example.COM',
        port: 443,
        protocol: 'tcp',
      ),
    );

    expect(decision.action, RoutingAction.block);
    expect(decision.matchedRuleId, 'rule-domain-block');
    expect(decision.explain, contains('domainExact=example.com'));
  });

  test('smaller priority wins when multiple rules match', () {
    final profile = RoutingProfile(
      id: 'routing-2',
      name: 'Priority Routing',
      mode: RoutingMode.rule,
      defaultAction: RoutingAction.proxy,
      globalAction: RoutingAction.proxy,
      policyGroups: const <RoutingPolicyGroup>[],
      rules: <RoutingRule>[
        _rule(
          id: 'rule-suffix-direct',
          priority: 80,
          match: const RoutingRuleMatch(domainSuffix: '.com'),
          action: const RoutingRuleAction.direct(RoutingAction.direct),
        ),
        _rule(
          id: 'rule-exact-block',
          priority: 5,
          match: const RoutingRuleMatch(domainExact: 'video.example.com'),
          action: const RoutingRuleAction.direct(RoutingAction.block),
        ),
      ],
      updatedAt: DateTime.parse('2026-04-15T00:00:00.000Z'),
    );

    final decision = engine.resolve(
      profile: profile,
      request: const RoutingRequestMetadata(
        host: 'video.example.com',
        port: 443,
        protocol: 'tcp',
      ),
    );

    expect(decision.action, RoutingAction.block);
    expect(decision.matchedRuleId, 'rule-exact-block');
  });

  test('policy-group rule resolves to policy group action', () {
    final profile = RoutingProfile(
      id: 'routing-3',
      name: 'Policy Group Routing',
      mode: RoutingMode.rule,
      defaultAction: RoutingAction.proxy,
      globalAction: RoutingAction.proxy,
      policyGroups: const <RoutingPolicyGroup>[
        RoutingPolicyGroup(
          id: 'domestic-direct',
          name: 'Domestic Direct',
          action: RoutingAction.direct,
        ),
      ],
      rules: <RoutingRule>[
        _rule(
          id: 'rule-cn',
          priority: 10,
          match: const RoutingRuleMatch(domainSuffix: '.cn'),
          action: const RoutingRuleAction.policyGroup('domestic-direct'),
        ),
      ],
      updatedAt: DateTime.parse('2026-04-15T00:00:00.000Z'),
    );

    final decision = engine.resolve(
      profile: profile,
      request: const RoutingRequestMetadata(
        host: 'news.sina.cn',
        port: 443,
        protocol: 'tcp',
      ),
    );

    expect(decision.action, RoutingAction.direct);
    expect(decision.matchedRuleId, 'rule-cn');
    expect(decision.policyGroupId, 'domestic-direct');
  });

  test('ip cidr matcher works for ipv4 source ip metadata', () {
    final profile = RoutingProfile(
      id: 'routing-4',
      name: 'IP Routing',
      mode: RoutingMode.rule,
      defaultAction: RoutingAction.proxy,
      globalAction: RoutingAction.proxy,
      policyGroups: const <RoutingPolicyGroup>[],
      rules: <RoutingRule>[
        _rule(
          id: 'rule-private-ip',
          priority: 10,
          match: const RoutingRuleMatch(ipCidr: '10.0.0.0/8'),
          action: const RoutingRuleAction.direct(RoutingAction.direct),
        ),
      ],
      updatedAt: DateTime.parse('2026-04-15T00:00:00.000Z'),
    );

    final decision = engine.resolve(
      profile: profile,
      request: const RoutingRequestMetadata(
        host: 'internal.example',
        ip: '10.1.2.3',
        port: 443,
        protocol: 'tcp',
      ),
    );

    expect(decision.action, RoutingAction.direct);
    expect(decision.matchedRuleId, 'rule-private-ip');
  });

  test('disabled rules are ignored and fallback uses default action', () {
    final profile = RoutingProfile(
      id: 'routing-5',
      name: 'Disabled Rule Routing',
      mode: RoutingMode.rule,
      defaultAction: RoutingAction.proxy,
      globalAction: RoutingAction.proxy,
      policyGroups: const <RoutingPolicyGroup>[],
      rules: <RoutingRule>[
        _rule(
          id: 'rule-disabled-block',
          priority: 1,
          enabled: false,
          match: const RoutingRuleMatch(domainExact: 'blocked.example'),
          action: const RoutingRuleAction.direct(RoutingAction.block),
        ),
      ],
      updatedAt: DateTime.parse('2026-04-15T00:00:00.000Z'),
    );

    final decision = engine.resolve(
      profile: profile,
      request: const RoutingRequestMetadata(
        host: 'blocked.example',
        port: 443,
        protocol: 'tcp',
      ),
    );

    expect(decision.action, RoutingAction.proxy);
    expect(decision.matchedRuleId, isNull);
  });

  test('direct mode short-circuits rules and always chooses direct', () {
    final profile = RoutingProfile(
      id: 'routing-6',
      name: 'Direct Mode',
      mode: RoutingMode.direct,
      defaultAction: RoutingAction.proxy,
      globalAction: RoutingAction.proxy,
      policyGroups: const <RoutingPolicyGroup>[],
      rules: <RoutingRule>[
        _rule(
          id: 'rule-would-block',
          priority: 1,
          match: const RoutingRuleMatch(domainExact: 'example.com'),
          action: const RoutingRuleAction.direct(RoutingAction.block),
        ),
      ],
      updatedAt: DateTime.parse('2026-04-15T00:00:00.000Z'),
    );

    final decision = engine.resolve(
      profile: profile,
      request: const RoutingRequestMetadata(
        host: 'example.com',
        port: 443,
        protocol: 'tcp',
      ),
    );

    expect(decision.action, RoutingAction.direct);
    expect(decision.matchedRuleId, isNull);
    expect(decision.explain, contains('mode=direct'));
  });
}
