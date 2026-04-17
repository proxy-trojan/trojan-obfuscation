import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/routing/testing/domain/routing_probe_models.dart';
import 'package:trojan_pro_client/features/routing/testing/platform/routing_probe_adapter_linux.dart';
import 'package:trojan_pro_client/features/routing/testing/platform/routing_probe_adapter_macos.dart';
import 'package:trojan_pro_client/features/routing/testing/platform/routing_probe_adapter_windows.dart';

void main() {
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

  test('linux adapter reports runtime-true posture', () async {
    const adapter = RoutingProbeAdapterLinux();
    final observation = await adapter.executeProbe(scenario);
    expect(observation.runtimePosture, RoutingProbeRuntimePosture.runtimeTrue);
  });

  test('windows adapter reports runtime-true posture', () async {
    const adapter = RoutingProbeAdapterWindows();
    final observation = await adapter.executeProbe(scenario);
    expect(observation.runtimePosture, RoutingProbeRuntimePosture.runtimeTrue);
  });

  test('macos adapter reports runtime-true posture', () async {
    const adapter = RoutingProbeAdapterMacos();
    final observation = await adapter.executeProbe(scenario);
    expect(observation.runtimePosture, RoutingProbeRuntimePosture.runtimeTrue);
  });
}
