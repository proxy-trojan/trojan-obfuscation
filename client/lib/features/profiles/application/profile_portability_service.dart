import 'dart:convert';

import '../domain/client_profile.dart';
import 'profile_import_bundle.dart';

class ProfilePortabilityService {
  String exportProfile(ClientProfile profile) {
    final payload = <String, Object?>{
      'version': 1,
      'kind': 'trojan-pro-client-profile',
      'profile': {
        'id': profile.id,
        'name': profile.name,
        'serverHost': profile.serverHost,
        'serverPort': profile.serverPort,
        'sni': profile.sni,
        'localSocksPort': profile.localSocksPort,
        'verifyTls': profile.verifyTls,
        'notes': profile.notes,
        'updatedAt': profile.updatedAt.toIso8601String(),
      },
      'secrets': {
        'trojanPasswordIncluded': false,
        'sourceDeviceHadStoredPassword': profile.hasStoredPassword,
        'importBehavior': 'reenter_or_restore_secure_storage',
      },
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  ClientProfile importProfile(String text) => importBundle(text).profile;

  ProfileImportBundle importBundle(String text) {
    final decoded = jsonDecode(text) as Map<String, dynamic>;
    final profile = decoded['profile'] as Map<String, dynamic>;
    final secrets = (decoded['secrets'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

    return ProfileImportBundle(
      profile: ClientProfile(
        id: (profile['id'] as String?) ?? 'imported-${DateTime.now().microsecondsSinceEpoch}',
        name: (profile['name'] as String?) ?? 'Imported Profile',
        serverHost: (profile['serverHost'] as String?) ?? 'example.com',
        serverPort: (profile['serverPort'] as num?)?.toInt() ?? 443,
        sni: (profile['sni'] as String?) ?? 'example.com',
        localSocksPort: (profile['localSocksPort'] as num?)?.toInt() ?? 1080,
        verifyTls: (profile['verifyTls'] as bool?) ?? true,
        notes: (profile['notes'] as String?) ?? '',
        updatedAt: DateTime.tryParse((profile['updatedAt'] as String?) ?? '') ?? DateTime.now(),
        hasStoredPassword: false,
      ),
      trojanPasswordIncluded: (secrets['trojanPasswordIncluded'] as bool?) ?? false,
      sourceDeviceHadStoredPassword: (secrets['sourceDeviceHadStoredPassword'] as bool?) ?? false,
      importBehavior: secrets['importBehavior'] as String?,
    );
  }
}
