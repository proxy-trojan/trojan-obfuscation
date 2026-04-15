import 'dart:convert';

import '../../routing/application/routing_profile_codec.dart';
import '../../routing/domain/routing_models.dart';
import '../../routing/domain/routing_profile_config.dart';
import '../domain/client_profile.dart';

class ProfileSerialization {
  ProfileSerialization({RoutingProfileCodec? routingCodec})
      : _routingCodec = routingCodec ?? const RoutingProfileCodec();

  final RoutingProfileCodec _routingCodec;

  List<ClientProfile> decodeProfileList(String text) {
    final decoded = jsonDecode(text) as Map<String, dynamic>;
    final items = (decoded['profiles'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((raw) => Map<String, dynamic>.from(raw));
    return items.map(_fromJson).toList(growable: false);
  }

  String encodeProfileList(List<ClientProfile> profiles) {
    final payload = <String, Object?>{
      'version': 2,
      'profiles': profiles.map(_toJson).toList(growable: false),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  ClientProfile _fromJson(Map<String, dynamic> json) {
    return ClientProfile(
      id: (json['id'] as String?) ??
          'profile-${DateTime.now().microsecondsSinceEpoch}',
      name: (json['name'] as String?) ?? 'Imported Profile',
      serverHost: (json['serverHost'] as String?) ?? 'example.com',
      serverPort: (json['serverPort'] as num?)?.toInt() ?? 443,
      sni: (json['sni'] as String?) ?? 'example.com',
      localSocksPort: (json['localSocksPort'] as num?)?.toInt() ?? 1080,
      verifyTls: (json['verifyTls'] as bool?) ?? true,
      notes: (json['notes'] as String?) ?? '',
      updatedAt: DateTime.tryParse((json['updatedAt'] as String?) ?? '') ??
          DateTime.now(),
      hasStoredPassword: (json['hasStoredPassword'] as bool?) ?? false,
      routing: _routingCodec.decodeFromObject(json['routing']),
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
      'hasStoredPassword': profile.hasStoredPassword,
      'routing': _routingCodec.encodeToJsonMap(
        _normalizeRouting(profile.routing),
      ),
    };
  }

  RoutingProfileConfig _normalizeRouting(RoutingProfileConfig routing) {
    final validGroupIds = routing.policyGroups.map((group) => group.id).toSet();
    final normalizedRules = routing.rules.map((rule) {
      if (!rule.action.usesPolicyGroup) {
        return rule;
      }
      final targetGroupId = rule.action.policyGroupId!.trim();
      if (validGroupIds.contains(targetGroupId)) {
        return rule;
      }
      return RoutingRule(
        id: rule.id,
        name: rule.name,
        enabled: rule.enabled,
        priority: rule.priority,
        match: rule.match,
        action: RoutingRuleAction.direct(routing.defaultAction),
      );
    }).toList(growable: false)
      ..sort((a, b) {
        final byPriority = a.priority.compareTo(b.priority);
        if (byPriority != 0) return byPriority;
        return a.id.compareTo(b.id);
      });

    return RoutingProfileConfig(
      mode: routing.mode,
      defaultAction: routing.defaultAction,
      globalAction: routing.globalAction,
      policyGroups: List<RoutingPolicyGroup>.unmodifiable(routing.policyGroups),
      rules: List<RoutingRule>.unmodifiable(normalizedRules),
    );
  }
}
