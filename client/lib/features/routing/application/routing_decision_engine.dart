import 'dart:io';

import '../domain/routing_models.dart';

class RoutingDecisionEngine {
  const RoutingDecisionEngine();

  RoutingDecision resolve({
    required RoutingProfile profile,
    required RoutingRequestMetadata request,
  }) {
    switch (profile.mode) {
      case RoutingMode.direct:
        return const RoutingDecision(
          action: RoutingAction.direct,
          explain: 'mode=direct -> action=direct',
        );
      case RoutingMode.global:
        return RoutingDecision(
          action: profile.globalAction,
          explain: 'mode=global -> action=${profile.globalAction.name}',
        );
      case RoutingMode.rule:
        break;
    }

    final sortedRules = profile.rules.where((rule) => rule.enabled).toList()
      ..sort((a, b) {
        final byPriority = a.priority.compareTo(b.priority);
        if (byPriority != 0) return byPriority;
        return a.id.compareTo(b.id);
      });

    for (final rule in sortedRules) {
      final matchResult = _matchesRule(rule.match, request);
      if (!matchResult.matched) {
        continue;
      }

      if (rule.action.usesPolicyGroup) {
        final policyGroupId = rule.action.policyGroupId!.trim();
        final policyGroup = _findPolicyGroup(profile, policyGroupId);
        if (policyGroup != null) {
          return RoutingDecision(
            action: policyGroup.action,
            matchedRuleId: rule.id,
            policyGroupId: policyGroup.id,
            explain:
                'mode=rule matchedRule=${rule.id} ${matchResult.explain} -> policyGroup=${policyGroup.id} action=${policyGroup.action.name}',
          );
        }

        return RoutingDecision(
          action: profile.defaultAction,
          matchedRuleId: rule.id,
          policyGroupId: policyGroupId,
          explain:
              'mode=rule matchedRule=${rule.id} ${matchResult.explain} -> missingPolicyGroup=$policyGroupId fallback=defaultAction:${profile.defaultAction.name}',
        );
      }

      final directAction = rule.action.directAction ?? profile.defaultAction;
      return RoutingDecision(
        action: directAction,
        matchedRuleId: rule.id,
        explain:
            'mode=rule matchedRule=${rule.id} ${matchResult.explain} -> action=${directAction.name}',
      );
    }

    return RoutingDecision(
      action: profile.defaultAction,
      explain:
          'mode=rule no_rule_matched -> defaultAction=${profile.defaultAction.name}',
    );
  }

  RoutingPolicyGroup? _findPolicyGroup(
    RoutingProfile profile,
    String policyGroupId,
  ) {
    for (final policyGroup in profile.policyGroups) {
      if (policyGroup.id == policyGroupId) {
        return policyGroup;
      }
    }
    return null;
  }

  _RoutingRuleMatchResult _matchesRule(
    RoutingRuleMatch match,
    RoutingRequestMetadata request,
  ) {
    if (!match.hasAnyConstraint) {
      return const _RoutingRuleMatchResult.noMatch();
    }

    final explainTokens = <String>[];
    final normalizedHost = _normalizeHost(request.host);

    final domainExact = _normalizeMaybe(match.domainExact);
    if (domainExact != null) {
      if (normalizedHost != domainExact) {
        return const _RoutingRuleMatchResult.noMatch();
      }
      explainTokens.add('domainExact=$domainExact');
    }

    final domainSuffixRaw = _normalizeMaybe(match.domainSuffix);
    if (domainSuffixRaw != null) {
      final domainSuffix = _normalizeSuffix(domainSuffixRaw);
      final suffixMatch = normalizedHost.endsWith(domainSuffix) ||
          normalizedHost == domainSuffix.substring(1);
      if (!suffixMatch) {
        return const _RoutingRuleMatchResult.noMatch();
      }
      explainTokens.add('domainSuffix=$domainSuffixRaw');
    }

    final domainKeyword = _normalizeMaybe(match.domainKeyword);
    if (domainKeyword != null) {
      if (!normalizedHost.contains(domainKeyword)) {
        return const _RoutingRuleMatchResult.noMatch();
      }
      explainTokens.add('domainKeyword=$domainKeyword');
    }

    final domainRegex = _normalizeMaybe(match.domainRegex);
    if (domainRegex != null) {
      RegExp regex;
      try {
        regex = RegExp(domainRegex, caseSensitive: false);
      } on FormatException {
        return const _RoutingRuleMatchResult.noMatch();
      }
      if (!regex.hasMatch(request.host)) {
        return const _RoutingRuleMatchResult.noMatch();
      }
      explainTokens.add('domainRegex=$domainRegex');
    }

    final ipCidr = _normalizeMaybe(match.ipCidr);
    if (ipCidr != null) {
      final requestIp = _normalizeMaybe(request.ip);
      if (requestIp == null || !_ipInCidr(requestIp, ipCidr)) {
        return const _RoutingRuleMatchResult.noMatch();
      }
      explainTokens.add('ipCidr=$ipCidr');
    }

    if (match.port != null) {
      if (request.port != match.port) {
        return const _RoutingRuleMatchResult.noMatch();
      }
      explainTokens.add('port=${match.port}');
    }

    final expectedProtocol = _normalizeMaybe(match.protocol);
    if (expectedProtocol != null) {
      final protocol = _normalizeMaybe(request.protocol) ?? '';
      if (protocol != expectedProtocol) {
        return const _RoutingRuleMatchResult.noMatch();
      }
      explainTokens.add('protocol=$expectedProtocol');
    }

    final expectedProcessName = _normalizeMaybe(match.processName);
    if (expectedProcessName != null) {
      final processName = _normalizeMaybe(request.processName);
      if (processName != expectedProcessName) {
        return const _RoutingRuleMatchResult.noMatch();
      }
      explainTokens.add('processName=$expectedProcessName');
    }

    final expectedProcessPath = _normalizeMaybe(match.processPath);
    if (expectedProcessPath != null) {
      final processPath = _normalizeMaybe(request.processPath);
      if (processPath != expectedProcessPath) {
        return const _RoutingRuleMatchResult.noMatch();
      }
      explainTokens.add('processPath=$expectedProcessPath');
    }

    return _RoutingRuleMatchResult.match(explainTokens.join(' '));
  }

  String _normalizeHost(String host) {
    final value = host.trim().toLowerCase();
    if (value.endsWith('.')) {
      return value.substring(0, value.length - 1);
    }
    return value;
  }

  String _normalizeSuffix(String suffix) {
    final value = suffix.trim().toLowerCase();
    if (value.startsWith('.')) {
      return value;
    }
    return '.$value';
  }

  String? _normalizeMaybe(String? value) {
    if (value == null) return null;
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    return normalized;
  }

  bool _ipInCidr(String ipValue, String cidrValue) {
    final delimiter = cidrValue.indexOf('/');
    if (delimiter <= 0 || delimiter == cidrValue.length - 1) {
      return false;
    }

    final networkValue = cidrValue.substring(0, delimiter).trim();
    final prefixValue = cidrValue.substring(delimiter + 1).trim();
    final prefixBits = int.tryParse(prefixValue);
    if (prefixBits == null) {
      return false;
    }

    final ip = InternetAddress.tryParse(ipValue.trim());
    final network = InternetAddress.tryParse(networkValue);
    if (ip == null || network == null) {
      return false;
    }
    if (ip.type != network.type) {
      return false;
    }

    final ipBytes = ip.rawAddress;
    final networkBytes = network.rawAddress;
    final totalBits = ipBytes.length * 8;
    if (prefixBits < 0 || prefixBits > totalBits) {
      return false;
    }

    var remainingBits = prefixBits;
    for (var index = 0; index < ipBytes.length; index++) {
      if (remainingBits <= 0) {
        break;
      }
      final mask =
          remainingBits >= 8 ? 0xFF : ((0xFF << (8 - remainingBits)) & 0xFF);
      if ((ipBytes[index] & mask) != (networkBytes[index] & mask)) {
        return false;
      }
      remainingBits -= 8;
    }

    return true;
  }
}

class _RoutingRuleMatchResult {
  const _RoutingRuleMatchResult.match(this.explain) : matched = true;

  const _RoutingRuleMatchResult.noMatch()
      : matched = false,
        explain = '';

  final bool matched;
  final String explain;
}
