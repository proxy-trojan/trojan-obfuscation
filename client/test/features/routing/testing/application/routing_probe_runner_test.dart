import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/routing/testing/application/routing_probe_runner.dart';
import 'package:trojan_pro_client/features/routing/testing/application/routing_probe_scenarios.dart';
import 'package:trojan_pro_client/features/routing/testing/platform/routing_probe_adapter_linux.dart';

void main() {
  test('runner executes core scenarios and emits evidence list', () async {
    final runner = RoutingProbeRunner(
      adapters: const [RoutingProbeAdapterLinux()],
    );

    final records = await runner.runBatch(routingProbeCoreScenarios);

    expect(records, isNotEmpty);
    expect(records.first.scenarioId, isNotEmpty);
  });
}
