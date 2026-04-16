import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/routing/testing/domain/routing_probe_models.dart';
import 'package:trojan_pro_client/features/routing/testing/platform/routing_probe_adapter_macos.dart';
import 'package:trojan_pro_client/features/routing/testing/platform/routing_probe_adapter_windows.dart';

void main() {
  test('windows and mac adapters provide deterministic platform identity',
      () async {
    const windows = RoutingProbeAdapterWindows();
    const macos = RoutingProbeAdapterMacos();

    expect(windows.platform, RoutingProbePlatform.windows);
    expect(macos.platform, RoutingProbePlatform.macos);
  });
}
