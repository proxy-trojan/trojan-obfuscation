import 'routing_models.dart';

class RoutingProfileConfig {
  const RoutingProfileConfig({
    required this.mode,
    required this.defaultAction,
    required this.globalAction,
    required this.policyGroups,
    required this.rules,
  });

  final RoutingMode mode;
  final RoutingAction defaultAction;
  final RoutingAction globalAction;
  final List<RoutingPolicyGroup> policyGroups;
  final List<RoutingRule> rules;

  static const RoutingProfileConfig defaults = RoutingProfileConfig(
    mode: RoutingMode.rule,
    defaultAction: RoutingAction.proxy,
    globalAction: RoutingAction.proxy,
    policyGroups: <RoutingPolicyGroup>[],
    rules: <RoutingRule>[],
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoutingProfileConfig &&
          runtimeType == other.runtimeType &&
          mode == other.mode &&
          defaultAction == other.defaultAction &&
          globalAction == other.globalAction &&
          _listEquals(policyGroups, other.policyGroups) &&
          _listEquals(rules, other.rules);

  @override
  int get hashCode => Object.hash(
        mode,
        defaultAction,
        globalAction,
        Object.hashAll(policyGroups),
        Object.hashAll(rules),
      );

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
