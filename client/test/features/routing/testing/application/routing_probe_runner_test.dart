import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/routing/testing/application/routing_probe_runner.dart';
import 'package:trojan_pro_client/features/routing/testing/application/routing_probe_scenarios.dart';
import 'package:trojan_pro_client/features/routing/testing/platform/routing_probe_adapter_linux.dart';

void main() {
  test('runner executes core scenarios and emits evidence list', () async {
    const runner = RoutingProbeRunner(
      adapters: [RoutingProbeAdapterLinux()],
    );

    final records = await runner.runBatch(routingProbeCoreScenarios);

    expect(records, isNotEmpty);
    expect(records.first.scenarioId, isNotEmpty);
  });

  test('mini smoke returns pass when all scenarios match expectation', () async {
    const runner = RoutingProbeRunner(
      adapters: [RoutingProbeAdapterLinux()],
    );

    final result = await runner.runMiniSmoke(routingProbeCoreScenarios);

    expect(result.passed, isTrue);
    expect(result.reason, contains('passed'));
    expect(result.evidence, isNotEmpty);
  });
}
