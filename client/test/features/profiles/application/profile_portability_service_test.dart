import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/profiles/application/profile_portability_service.dart';
import 'package:trojan_pro_client/features/profiles/domain/client_profile.dart';

ClientProfile _profile({
  String id = 'profile-1',
  String name = 'HK Node',
  String host = 'hk.example.com',
  int serverPort = 443,
  int localSocksPort = 1080,
  bool hasStoredPassword = false,
}) {
  return ClientProfile(
    id: id,
    name: name,
    serverHost: host,
    serverPort: serverPort,
    sni: host,
    localSocksPort: localSocksPort,
    verifyTls: true,
    updatedAt: DateTime.parse('2026-03-13T00:00:00.000Z'),
    hasStoredPassword: hasStoredPassword,
  );
}

void main() {
  test(
      'export profile omits password material and marks secret policy explicitly',
      () {
    final service = ProfilePortabilityService();

    final exported = service.exportProfile(
      _profile(hasStoredPassword: true),
    );

    final map = jsonDecode(exported) as Map<String, dynamic>;
    expect(map['kind'], 'trojan-pro-client-profile');
    final secrets = map['secrets'] as Map<String, dynamic>;
    expect(secrets['trojanPasswordIncluded'], false);
    expect(secrets['sourceDeviceHadStoredPassword'], true);
    expect(exported, isNot(contains('trojan-password')));
    expect(exported, isNot(contains('super-secret')));
  });

  test('import bundle preserves profile fields and secret-handoff metadata',
      () {
    final service = ProfilePortabilityService();

    final bundle = service.importBundle('''
{
  "version": 1,
  "kind": "trojan-pro-client-profile",
  "profile": {
    "id": "imported-1",
    "name": "Imported Profile",
    "serverHost": "jp.example.com",
    "serverPort": 8443,
    "sni": "cdn.example.com",
    "localSocksPort": 2080,
    "verifyTls": false,
    "notes": "from another device",
    "updatedAt": "2026-03-12T23:59:59.000Z"
  },
  "secrets": {
    "trojanPasswordIncluded": false,
    "sourceDeviceHadStoredPassword": true,
    "importBehavior": "reenter_or_restore_secure_storage"
  }
}
''');

    expect(bundle.profile.id, 'imported-1');
    expect(bundle.profile.name, 'Imported Profile');
    expect(bundle.profile.serverHost, 'jp.example.com');
    expect(bundle.profile.serverPort, 8443);
    expect(bundle.profile.localSocksPort, 2080);
    expect(bundle.profile.verifyTls, isFalse);
    expect(bundle.trojanPasswordIncluded, isFalse);
    expect(bundle.sourceDeviceHadStoredPassword, isTrue);
    expect(bundle.importBehavior, 'reenter_or_restore_secure_storage');
  });

  test('import bundle applies safe defaults when optional fields are missing',
      () {
    final service = ProfilePortabilityService();

    final bundle = service.importBundle('''
{
  "profile": {
    "name": "Minimal"
  }
}
''');

    expect(bundle.profile.name, 'Minimal');
    expect(bundle.profile.serverHost, 'example.com');
    expect(bundle.profile.serverPort, 443);
    expect(bundle.profile.localSocksPort, 1080);
    expect(bundle.profile.hasStoredPassword, isFalse);
    expect(bundle.trojanPasswordIncluded, isFalse);
    expect(bundle.sourceDeviceHadStoredPassword, isFalse);
  });

  test('exportProfiles builds profile bundle payload without raw secrets', () {
    final service = ProfilePortabilityService();

    final exported = service.exportProfiles(<ClientProfile>[
      _profile(id: 'profile-hk', name: 'Hong Kong', hasStoredPassword: true),
      _profile(id: 'profile-us', name: 'United States'),
    ]);

    final map = jsonDecode(exported) as Map<String, dynamic>;
    expect(map['kind'], 'trojan-pro-client-profile-bundle');

    final profiles = map['profiles'] as List<dynamic>;
    expect(profiles, hasLength(2));

    final first = profiles.first as Map<String, dynamic>;
    final firstSecrets = first['secrets'] as Map<String, dynamic>;
    expect(firstSecrets['trojanPasswordIncluded'], false);
    expect(firstSecrets['sourceDeviceHadStoredPassword'], true);

    expect(exported, isNot(contains('super-secret')));
    expect(exported, isNot(contains('trojan-password')));
  });
}
