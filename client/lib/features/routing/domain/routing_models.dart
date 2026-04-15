enum RoutingMode {
  rule,
  global,
  direct,
}

enum RoutingAction {
  proxy,
  direct,
  block,
}

class RoutingPolicyGroup {
  const RoutingPolicyGroup({
    required this.id,
    required this.name,
    required this.action,
  });

  final String id;
  final String name;
  final RoutingAction action;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoutingPolicyGroup &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          action == other.action;

  @override
  int get hashCode => Object.hash(id, name, action);
}

class RoutingRuleMatch {
  const RoutingRuleMatch({
    this.domainExact,
    this.domainSuffix,
    this.domainKeyword,
    this.domainRegex,
    this.ipCidr,
    this.port,
    this.protocol,
    this.processName,
    this.processPath,
  });

  final String? domainExact;
  final String? domainSuffix;
  final String? domainKeyword;
  final String? domainRegex;
  final String? ipCidr;
  final int? port;
  final String? protocol;
  final String? processName;
  final String? processPath;

  bool get hasAnyConstraint =>
      (domainExact != null && domainExact!.trim().isNotEmpty) ||
      (domainSuffix != null && domainSuffix!.trim().isNotEmpty) ||
      (domainKeyword != null && domainKeyword!.trim().isNotEmpty) ||
      (domainRegex != null && domainRegex!.trim().isNotEmpty) ||
      (ipCidr != null && ipCidr!.trim().isNotEmpty) ||
      port != null ||
      (protocol != null && protocol!.trim().isNotEmpty) ||
      (processName != null && processName!.trim().isNotEmpty) ||
      (processPath != null && processPath!.trim().isNotEmpty);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoutingRuleMatch &&
          runtimeType == other.runtimeType &&
          domainExact == other.domainExact &&
          domainSuffix == other.domainSuffix &&
          domainKeyword == other.domainKeyword &&
          domainRegex == other.domainRegex &&
          ipCidr == other.ipCidr &&
          port == other.port &&
          protocol == other.protocol &&
          processName == other.processName &&
          processPath == other.processPath;

  @override
  int get hashCode => Object.hash(
        domainExact,
        domainSuffix,
        domainKeyword,
        domainRegex,
        ipCidr,
        port,
        protocol,
        processName,
        processPath,
      );
}

class RoutingRuleAction {
  const RoutingRuleAction.direct(this.directAction) : policyGroupId = null;

  const RoutingRuleAction.policyGroup(this.policyGroupId) : directAction = null;

  final RoutingAction? directAction;
  final String? policyGroupId;

  bool get usesPolicyGroup =>
      policyGroupId != null && policyGroupId!.trim().isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoutingRuleAction &&
          runtimeType == other.runtimeType &&
          directAction == other.directAction &&
          policyGroupId == other.policyGroupId;

  @override
  int get hashCode => Object.hash(directAction, policyGroupId);
}

class RoutingRule {
  const RoutingRule({
    required this.id,
    required this.name,
    required this.enabled,
    required this.priority,
    required this.match,
    required this.action,
  });

  final String id;
  final String name;
  final bool enabled;
  final int priority;
  final RoutingRuleMatch match;
  final RoutingRuleAction action;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoutingRule &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          enabled == other.enabled &&
          priority == other.priority &&
          match == other.match &&
          action == other.action;

  @override
  int get hashCode => Object.hash(id, name, enabled, priority, match, action);
}

class RoutingProfile {
  const RoutingProfile({
    required this.id,
    required this.name,
    required this.mode,
    required this.defaultAction,
    required this.globalAction,
    required this.policyGroups,
    required this.rules,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final RoutingMode mode;
  final RoutingAction defaultAction;
  final RoutingAction globalAction;
  final List<RoutingPolicyGroup> policyGroups;
  final List<RoutingRule> rules;
  final DateTime updatedAt;
}

class RoutingRequestMetadata {
  const RoutingRequestMetadata({
    required this.host,
    required this.port,
    required this.protocol,
    this.ip,
    this.processName,
    this.processPath,
  });

  final String host;
  final String? ip;
  final int port;
  final String protocol;
  final String? processName;
  final String? processPath;
}

class RoutingDecision {
  const RoutingDecision({
    required this.action,
    required this.explain,
    this.matchedRuleId,
    this.policyGroupId,
  });

  final RoutingAction action;
  final String explain;
  final String? matchedRuleId;
  final String? policyGroupId;
}
