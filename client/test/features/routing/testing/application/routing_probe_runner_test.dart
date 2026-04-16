import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/routing/testing/application/routing_probe_scenarios.dart';

void main() {
  test('core probe scenarios contains expected 6 baseline cases', () {
    final scenarios = routingProbeCoreScenarios;

    expect(scenarios, hasLength(6));
    expect(
        scenarios.map((s) => s.id),
        containsAll(<String>[
          'rule-direct',
          'rule-proxy',
          'rule-policy-group',
          'policy-group-missing-fallback',
          'no-rule-default',
          'block-action',
        ]));
  });
}
