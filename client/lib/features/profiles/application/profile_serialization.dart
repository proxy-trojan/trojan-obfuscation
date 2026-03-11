import 'dart:convert';

import '../domain/client_profile.dart';

class ProfileSerialization {
  List<ClientProfile> decodeProfileList(String text) {
    final decoded = jsonDecode(text) as Map<String, dynamic>;
    final items = (decoded['profiles'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();
    return items.map(_fromJson).toList();
  }

  String encodeProfileList(List<ClientProfile> profiles) {
    final payload = <String, Object?>{
      'version': 1,
      'profiles': profiles.map(_toJson).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  ClientProfile _fromJson(Map<String, dynamic> json) {
    return ClientProfile(
      id: (json['id'] as String?) ?? 'profile-${DateTime.now().microsecondsSinceEpoch}',
      name: (json['name'] as String?) ?? 'Imported Profile',
      serverHost: (json['serverHost'] as String?) ?? 'example.com',
      serverPort: (json['serverPort'] as num?)?.toInt() ?? 443,
      sni: (json['sni'] as String?) ?? 'example.com',
      localSocksPort: (json['localSocksPort'] as num?)?.toInt() ?? 1080,
      verifyTls: (json['verifyTls'] as bool?) ?? true,
      notes: (json['notes'] as String?) ?? '',
      updatedAt: DateTime.tryParse((json['updatedAt'] as String?) ?? '') ?? DateTime.now(),
    );
  }

  Map<String, Object?> _toJson(ClientProfile profile) {
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
    };
  }
}
