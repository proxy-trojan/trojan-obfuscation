import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/routing/testing/domain/routing_probe_models.dart';
import 'package:trojan_pro_client/features/routing/testing/platform/routing_probe_adapter_linux.dart';

void main() {
  test('linux adapter can execute probe and produce observation', () async {
    const adapter = RoutingProbeAdapterLinux();
    const scenario = RoutingProbeScenario(
      id: 'rule-direct',
      host: 'direct.example.com',
      port: 443,
      protocol: 'tcp',
      expected: RoutingProbeExpectation(
        expectedAction: RoutingProbeAction.direct,
        expectedObservedResult: RoutingProbeObservedResult.direct,
      ),
    );

    final observation = await adapter.executeProbe(scenario);

    expect(observation.platform, RoutingProbePlatform.linux);
    expect(observation.scenarioId, scenario.id);
  });
}
