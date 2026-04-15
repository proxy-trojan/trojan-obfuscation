import '../domain/routing_models.dart';
import '../domain/routing_profile_config.dart';

class RoutingProfileCodec {
  const RoutingProfileCodec();

  RoutingProfileConfig decodeFromObject(Object? value) {
    if (value is Map<String, dynamic>) {
      return decodeFromJsonMap(value);
    }
    if (value is Map) {
      return decodeFromJsonMap(Map<String, dynamic>.from(value));
    }
    return RoutingProfileConfig.defaults;
  }

  RoutingProfileConfig decodeFromJsonMap(Map<String, dynamic> json) {
    final mode = _safeEnum(
      RoutingMode.values,
      json['mode'] as String?,
      RoutingMode.rule,
    );
    final defaultAction = _safeEnum(
      RoutingAction.values,
      json['defaultAction'] as String?,
      RoutingAction.proxy,
    );
    final globalAction = _safeEnum(
      RoutingAction.values,
      json['globalAction'] as String?,
      RoutingAction.proxy,
    );

    final policyGroups =
        (json['policyGroups'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map>()
            .map((raw) {
              final map = Map<String, dynamic>.from(raw);
              final id = (map['id'] as String?)?.trim();
              if (id == null || id.isEmpty) {
                return null;
              }
              return RoutingPolicyGroup(
                id: id,
                name: (map['name'] as String?)?.trim().isNotEmpty == true
                    ? (map['name'] as String).trim()
                    : id,
                action: _safeEnum(
                  RoutingAction.values,
                  map['action'] as String?,
                  RoutingAction.proxy,
                ),
              );
            })
            .whereType<RoutingPolicyGroup>()
            .toList(growable: false);

    final rules = (json['rules'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((raw) {
          final map = Map<String, dynamic>.from(raw);
          final id = (map['id'] as String?)?.trim();
          if (id == null || id.isEmpty) {
            return null;
          }

          final matchMap = _asStringDynamicMap(map['match']);
          final actionMap = _asStringDynamicMap(map['action']);

          final actionKind = (actionMap['kind'] as String?)?.trim();
          final action = actionKind == 'policyGroup'
              ? RoutingRuleAction.policyGroup(
                  (actionMap['policyGroupId'] as String?)?.trim(),
                )
              : RoutingRuleAction.direct(
                  _safeEnum(
                    RoutingAction.values,
                    actionMap['directAction'] as String?,
                    defaultAction,
                  ),
                );

          return RoutingRule(
            id: id,
            name: (map['name'] as String?)?.trim().isNotEmpty == true
                ? (map['name'] as String).trim()
                : id,
            enabled: (map['enabled'] as bool?) ?? true,
            priority: (map['priority'] as num?)?.toInt() ?? 100,
            match: RoutingRuleMatch(
              domainExact: (matchMap['domainExact'] as String?)?.trim(),
              domainSuffix: (matchMap['domainSuffix'] as String?)?.trim(),
              domainKeyword: (matchMap['domainKeyword'] as String?)?.trim(),
              domainRegex: (matchMap['domainRegex'] as String?)?.trim(),
              ipCidr: (matchMap['ipCidr'] as String?)?.trim(),
              port: (matchMap['port'] as num?)?.toInt(),
              protocol: (matchMap['protocol'] as String?)?.trim(),
              processName: (matchMap['processName'] as String?)?.trim(),
              processPath: (matchMap['processPath'] as String?)?.trim(),
            ),
            action: action,
          );
        })
        .whereType<RoutingRule>()
        .toList(growable: false)
      ..sort((a, b) {
        final byPriority = a.priority.compareTo(b.priority);
        if (byPriority != 0) return byPriority;
        return a.id.compareTo(b.id);
      });

    return RoutingProfileConfig(
      mode: mode,
      defaultAction: defaultAction,
      globalAction: globalAction,
      policyGroups: policyGroups,
      rules: rules,
    );
  }

  Map<String, Object?> encodeToJsonMap(RoutingProfileConfig config) {
    final sortedPolicyGroups = List<RoutingPolicyGroup>.from(
      config.policyGroups,
    )..sort((a, b) => a.id.compareTo(b.id));

    final sortedRules = List<RoutingRule>.from(config.rules)
      ..sort((a, b) {
        final byPriority = a.priority.compareTo(b.priority);
        if (byPriority != 0) return byPriority;
        return a.id.compareTo(b.id);
      });

    return <String, Object?>{
      'mode': config.mode.name,
      'defaultAction': config.defaultAction.name,
      'globalAction': config.globalAction.name,
      'policyGroups': sortedPolicyGroups
          .map(
            (group) => <String, Object?>{
              'id': group.id,
              'name': group.name,
              'action': group.action.name,
            },
          )
          .toList(growable: false),
      'rules': sortedRules
          .map(
            (rule) => <String, Object?>{
              'id': rule.id,
              'name': rule.name,
              'enabled': rule.enabled,
              'priority': rule.priority,
              'match': <String, Object?>{
                if ((rule.match.domainExact ?? '').trim().isNotEmpty)
                  'domainExact': rule.match.domainExact!.trim(),
                if ((rule.match.domainSuffix ?? '').trim().isNotEmpty)
                  'domainSuffix': rule.match.domainSuffix!.trim(),
                if ((rule.match.domainKeyword ?? '').trim().isNotEmpty)
                  'domainKeyword': rule.match.domainKeyword!.trim(),
                if ((rule.match.domainRegex ?? '').trim().isNotEmpty)
                  'domainRegex': rule.match.domainRegex!.trim(),
                if ((rule.match.ipCidr ?? '').trim().isNotEmpty)
                  'ipCidr': rule.match.ipCidr!.trim(),
                if (rule.match.port != null) 'port': rule.match.port,
                if ((rule.match.protocol ?? '').trim().isNotEmpty)
                  'protocol': rule.match.protocol!.trim(),
                if ((rule.match.processName ?? '').trim().isNotEmpty)
                  'processName': rule.match.processName!.trim(),
                if ((rule.match.processPath ?? '').trim().isNotEmpty)
                  'processPath': rule.match.processPath!.trim(),
              },
              'action': rule.action.usesPolicyGroup
                  ? <String, Object?>{
                      'kind': 'policyGroup',
                      'policyGroupId': rule.action.policyGroupId!.trim(),
                    }
                  : <String, Object?>{
                      'kind': 'direct',
                      'directAction':
                          (rule.action.directAction ?? config.defaultAction)
                              .name,
                    },
            },
          )
          .toList(growable: false),
    };
  }

  Map<String, dynamic> _asStringDynamicMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  T _safeEnum<T extends Enum>(List<T> values, String? name, T fallback) {
    if (name == null) return fallback;
    return values.asNameMap()[name] ?? fallback;
  }
}
