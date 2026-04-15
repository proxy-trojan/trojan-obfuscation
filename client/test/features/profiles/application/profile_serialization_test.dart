import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/profiles/application/profile_serialization.dart';
import 'package:trojan_pro_client/features/profiles/domain/client_profile.dart';

void main() {
  final serialization = ProfileSerialization();

  test('decode reads routing payload when present', () {
    const payload = '''
{
  "version": 2,
  "profiles": [
    {
      "id": "p1",
      "name": "Profile 1",
      "serverHost": "example.com",
      "serverPort": 443,
      "sni": "example.com",
      "localSocksPort": 1080,
      "verifyTls": true,
      "updatedAt": "2026-04-15T00:00:00.000Z",
      "routing": {
        "mode": "rule",
        "defaultAction": "proxy",
        "globalAction": "proxy",
        "policyGroups": [
          {"id": "g1", "name": "Domestic", "action": "direct"}
        ],
        "rules": [
          {
            "id": "r1",
            "name": "rule1",
            "enabled": true,
            "priority": 10,
            "match": {"domainSuffix": ".cn"},
            "action": {"kind": "policyGroup", "policyGroupId": "g1"}
          }
        ]
      }
    }
  ]
}
''';

    final decoded = serialization.decodeProfileList(payload);
    expect(decoded, hasLength(1));
    final profile = decoded.first;
    expect(profile.routing.mode.name, 'rule');
    expect(profile.routing.defaultAction.name, 'proxy');
    expect(profile.routing.policyGroups, hasLength(1));
    expect(profile.routing.policyGroups.first.id, 'g1');
    expect(profile.routing.rules, hasLength(1));
    expect(profile.routing.rules.first.id, 'r1');
    expect(profile.routing.rules.first.action.policyGroupId, 'g1');
  });

  test('decode falls back to safe default routing when field missing', () {
    const payload = '''
{
  "version": 1,
  "profiles": [
    {
      "id": "p2",
      "name": "Legacy",
      "serverHost": "legacy.example.com",
      "serverPort": 443,
      "sni": "legacy.example.com",
      "localSocksPort": 1080,
      "verifyTls": true,
      "updatedAt": "2026-04-15T00:00:00.000Z"
    }
  ]
}
''';

    final decoded = serialization.decodeProfileList(payload);
    final routing = decoded.first.routing;

    expect(routing.mode.name, 'rule');
    expect(routing.defaultAction.name, 'proxy');
    expect(routing.globalAction.name, 'proxy');
    expect(routing.rules, isEmpty);
    expect(routing.policyGroups, isEmpty);
  });

  test('encode includes routing block and keeps deterministic shape', () {
    final profile = ClientProfile(
      id: 'p3',
      name: 'Encode',
      serverHost: 'encode.example.com',
      serverPort: 443,
      sni: 'encode.example.com',
      localSocksPort: 1080,
      verifyTls: true,
      updatedAt: DateTime.parse('2026-04-15T00:00:00.000Z'),
    );

    final text = serialization.encodeProfileList(<ClientProfile>[profile]);

    expect(text, contains('"routing"'));
    expect(text, contains('"mode": "rule"'));
    expect(text, contains('"defaultAction": "proxy"'));
    expect(text, contains('"globalAction": "proxy"'));
  });
}
