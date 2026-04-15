import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/profiles/application/profile_portability_service.dart';
import 'package:trojan_pro_client/features/profiles/domain/client_profile.dart';
import 'package:trojan_pro_client/features/routing/domain/routing_models.dart';
import 'package:trojan_pro_client/features/routing/domain/routing_profile_config.dart';

ClientProfile _profileWithRouting() {
  return ClientProfile(
    id: 'profile-routing',
    name: 'Routing Profile',
    serverHost: 'example.com',
    serverPort: 443,
    sni: 'example.com',
    localSocksPort: 1080,
    verifyTls: true,
    updatedAt: DateTime.parse('2026-04-15T00:00:00.000Z'),
    routing: const RoutingProfileConfig(
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
          id: 'rule-cn',
          name: 'CN Direct',
          enabled: true,
          priority: 10,
          match: RoutingRuleMatch(domainSuffix: '.cn'),
          action: RoutingRuleAction.policyGroup('domestic'),
        ),
      ],
    ),
  );
}

void main() {
  final service = ProfilePortabilityService();

  test('exportProfile includes routing payload without secrets', () {
    final exported = service.exportProfile(_profileWithRouting());

    final decoded = jsonDecode(exported) as Map<String, dynamic>;
    final profile = decoded['profile'] as Map<String, dynamic>;
    final routing = profile['routing'] as Map<String, dynamic>?;

    expect(routing, isNotNull);
    expect(routing!['mode'], 'rule');
    expect(routing['defaultAction'], 'proxy');
    final rules = routing['rules'] as List<dynamic>;
    expect(rules, hasLength(1));
    expect((rules.first as Map<String, dynamic>)['id'], 'rule-cn');

    expect(exported, isNot(contains('trojan-password')));
    expect(exported, isNot(contains('super-secret')));
  });

  test('importBundle decodes routing payload and keeps semantics', () {
    final bundle = service.importBundle('''
{
  "version": 2,
  "kind": "trojan-pro-client-profile",
  "profile": {
    "id": "imported-routing",
    "name": "Imported Routing",
    "serverHost": "jp.example.com",
    "serverPort": 8443,
    "sni": "cdn.example.com",
    "localSocksPort": 2080,
    "verifyTls": false,
    "notes": "with routing",
    "updatedAt": "2026-04-15T00:00:00.000Z",
    "routing": {
      "mode": "rule",
      "defaultAction": "proxy",
      "globalAction": "proxy",
      "policyGroups": [
        {"id": "domestic", "name": "Domestic", "action": "direct"}
      ],
      "rules": [
        {
          "id": "rule-cn",
          "name": "CN Direct",
          "enabled": true,
          "priority": 10,
          "match": {"domainSuffix": ".cn"},
          "action": {"kind": "policyGroup", "policyGroupId": "domestic"}
        }
      ]
    }
  },
  "secrets": {
    "trojanPasswordIncluded": false,
    "sourceDeviceHadStoredPassword": true,
    "importBehavior": "reenter_or_restore_secure_storage"
  }
}
''');

    expect(bundle.profile.id, 'imported-routing');
    expect(bundle.profile.routing.policyGroups, hasLength(1));
    expect(bundle.profile.routing.policyGroups.first.id, 'domestic');
    expect(bundle.profile.routing.rules, hasLength(1));
    expect(bundle.profile.routing.rules.first.id, 'rule-cn');
  });
}
