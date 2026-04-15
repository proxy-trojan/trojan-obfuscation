import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/controller/application/trojan_client_config_renderer.dart';
import 'package:trojan_pro_client/features/profiles/domain/client_profile.dart';
import 'package:trojan_pro_client/features/routing/domain/routing_models.dart';
import 'package:trojan_pro_client/features/routing/domain/routing_profile_config.dart';

ClientProfile _profile({RoutingProfileConfig? routing}) {
  return ClientProfile(
    id: 'profile-1',
    name: 'Profile One',
    serverHost: 'example.com',
    serverPort: 443,
    sni: 'example.com',
    localSocksPort: 1080,
    verifyTls: true,
    updatedAt: DateTime.parse('2026-04-15T00:00:00.000Z'),
    routing: routing ?? RoutingProfileConfig.defaults,
  );
}

void main() {
  final renderer = TrojanClientConfigRenderer();

  test('render includes routing payload with safe defaults', () {
    final raw = renderer.render(
      profile: _profile(),
      password: 'super-secret',
    );

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final routing = decoded['routing'] as Map<String, dynamic>?;

    expect(routing, isNotNull);
    expect(routing!['mode'], 'rule');
    expect(routing['defaultAction'], 'proxy');
    expect(routing['globalAction'], 'proxy');
    expect(routing['policyGroups'], isEmpty);
    expect(routing['rules'], isEmpty);
  });

  test('render routing payload is deterministic and priority-sorted', () {
    const routing = RoutingProfileConfig(
      mode: RoutingMode.rule,
      defaultAction: RoutingAction.proxy,
      globalAction: RoutingAction.proxy,
      policyGroups: <RoutingPolicyGroup>[
        RoutingPolicyGroup(
          id: 'domestic',
          name: 'Domestic',
          action: RoutingAction.direct,
        ),
      ],
      rules: <RoutingRule>[
        RoutingRule(
          id: 'rule-late',
          name: 'late',
          enabled: true,
          priority: 100,
          match: RoutingRuleMatch(domainSuffix: '.com'),
          action: RoutingRuleAction.direct(RoutingAction.proxy),
        ),
        RoutingRule(
          id: 'rule-early',
          name: 'early',
          enabled: true,
          priority: 10,
          match: RoutingRuleMatch(domainSuffix: '.cn'),
          action: RoutingRuleAction.policyGroup('domestic'),
        ),
      ],
    );

    final raw = renderer.render(
      profile: _profile(routing: routing),
      password: 'super-secret',
    );

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final routingPayload = decoded['routing'] as Map<String, dynamic>;
    final rules = routingPayload['rules'] as List<dynamic>;

    expect(rules, hasLength(2));
    expect((rules[0] as Map<String, dynamic>)['id'], 'rule-early');
    expect((rules[1] as Map<String, dynamic>)['id'], 'rule-late');
  });
}
