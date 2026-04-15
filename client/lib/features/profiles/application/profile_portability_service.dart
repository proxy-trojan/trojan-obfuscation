import 'dart:convert';

import '../../routing/application/routing_profile_codec.dart';
import '../domain/client_profile.dart';
import 'profile_import_bundle.dart';

class ProfilePortabilityService {
  ProfilePortabilityService({RoutingProfileCodec? routingCodec})
      : _routingCodec = routingCodec ?? const RoutingProfileCodec();

  final RoutingProfileCodec _routingCodec;

  Map<String, Object?> _profilePayload(ClientProfile profile) {
    return <String, Object?>{
      'id': profile.id,
      'name': profile.name,
      'serverHost': profile.serverHost,
      'serverPort': profile.serverPort,
      'sni': profile.sni,
      'localSocksPort': profile.localSocksPort,
      'verifyTls': profile.verifyTls,
      'notes': profile.notes,
      'updatedAt': profile.updatedAt.toIso8601String(),
      'routing': _routingCodec.encodeToJsonMap(profile.routing),
    };
  }

  Map<String, Object?> _secretsPayload(ClientProfile profile) {
    return <String, Object?>{
      'trojanPasswordIncluded': false,
      'sourceDeviceHadStoredPassword': profile.hasStoredPassword,
      'importBehavior': 'reenter_or_restore_secure_storage',
    };
  }

  String exportProfile(ClientProfile profile) {
    final payload = <String, Object?>{
      'version': 2,
      'kind': 'trojan-pro-client-profile',
      'profile': _profilePayload(profile),
      'secrets': _secretsPayload(profile),
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  String exportProfiles(List<ClientProfile> profiles) {
    final payload = <String, Object?>{
      'version': 2,
      'kind': 'trojan-pro-client-profile-bundle',
      'profiles': profiles
          .map(
            (profile) => <String, Object?>{
              'profile': _profilePayload(profile),
              'secrets': _secretsPayload(profile),
            },
          )
          .toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  ClientProfile importProfile(String text) => importBundle(text).profile;

  ProfileImportBundle importBundle(String text) {
    final decoded = jsonDecode(text) as Map<String, dynamic>;
    final profile = decoded['profile'] as Map<String, dynamic>;
    final secrets = (decoded['secrets'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};

    return ProfileImportBundle(
      profile: ClientProfile(
        id: (profile['id'] as String?) ??
            'imported-${DateTime.now().microsecondsSinceEpoch}',
        name: (profile['name'] as String?) ?? 'Imported Profile',
        serverHost: (profile['serverHost'] as String?) ?? 'example.com',
        serverPort: (profile['serverPort'] as num?)?.toInt() ?? 443,
        sni: (profile['sni'] as String?) ?? 'example.com',
        localSocksPort: (profile['localSocksPort'] as num?)?.toInt() ?? 1080,
        verifyTls: (profile['verifyTls'] as bool?) ?? true,
        notes: (profile['notes'] as String?) ?? '',
        updatedAt: DateTime.tryParse((profile['updatedAt'] as String?) ?? '') ??
            DateTime.now(),
        hasStoredPassword: false,
        routing: _routingCodec.decodeFromObject(profile['routing']),
      ),
      trojanPasswordIncluded:
          (secrets['trojanPasswordIncluded'] as bool?) ?? false,
      sourceDeviceHadStoredPassword:
          (secrets['sourceDeviceHadStoredPassword'] as bool?) ?? false,
      importBehavior: secrets['importBehavior'] as String?,
    );
  }
}
