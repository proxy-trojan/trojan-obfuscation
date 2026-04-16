import '../domain/routing_models.dart';
import '../domain/routing_profile_config.dart';
import '../testing/domain/routing_probe_models.dart';
import 'routing_decision_engine.dart';

class RoutingDryRunChangedCase {
  const RoutingDryRunChangedCase({
    required this.scenarioId,
    required this.beforeAction,
    required this.afterAction,
    required this.beforeExplain,
    required this.afterExplain,
    this.beforeMatchedRuleId,
    this.afterMatchedRuleId,
  });

  final String scenarioId;
  final RoutingAction beforeAction;
  final RoutingAction afterAction;
  final String beforeExplain;
  final String afterExplain;
  final String? beforeMatchedRuleId;
  final String? afterMatchedRuleId;
}

class RoutingDryRunReport {
  const RoutingDryRunReport({required this.changedCases});

  final List<RoutingDryRunChangedCase> changedCases;
}

class RoutingDryRunService {
  const RoutingDryRunService({RoutingDecisionEngine? engine})
      : _engine = engine ?? const RoutingDecisionEngine();

  final RoutingDecisionEngine _engine;

  RoutingDryRunReport compare({
    required RoutingProfileConfig before,
    required RoutingProfileConfig after,
    required List<RoutingProbeScenario> scenarios,
  }) {
    final changedCases = <RoutingDryRunChangedCase>[];

    final beforeProfile = _toRoutingProfile(id: 'before', config: before);
    final afterProfile = _toRoutingProfile(id: 'after', config: after);

    for (final scenario in scenarios) {
      final request = RoutingRequestMetadata(
        host: scenario.host,
        port: scenario.port,
        protocol: scenario.protocol,
      );

      final beforeDecision = _engine.resolve(
        profile: beforeProfile,
        request: request,
      );
      final afterDecision = _engine.resolve(
        profile: afterProfile,
        request: request,
      );

      final actionChanged = beforeDecision.action != afterDecision.action;
      final ruleChanged = beforeDecision.matchedRuleId != afterDecision.matchedRuleId;
      if (!actionChanged && !ruleChanged) {
        continue;
      }

      changedCases.add(
        RoutingDryRunChangedCase(
          scenarioId: scenario.id,
          beforeAction: beforeDecision.action,
          afterAction: afterDecision.action,
          beforeExplain: beforeDecision.explain,
          afterExplain: afterDecision.explain,
          beforeMatchedRuleId: beforeDecision.matchedRuleId,
          afterMatchedRuleId: afterDecision.matchedRuleId,
        ),
      );
    }

    return RoutingDryRunReport(changedCases: changedCases);
  }

  RoutingProfile _toRoutingProfile({
    required String id,
    required RoutingProfileConfig config,
  }) {
    return RoutingProfile(
      id: id,
      name: id,
      mode: config.mode,
      defaultAction: config.defaultAction,
      globalAction: config.globalAction,
      policyGroups: config.policyGroups,
      rules: config.rules,
      updatedAt: DateTime.now(),
    );
  }
}
