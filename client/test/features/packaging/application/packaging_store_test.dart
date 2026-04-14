import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/packaging/application/packaging_store.dart';
import 'package:trojan_pro_client/features/packaging/domain/desktop_package_status.dart';
import 'package:trojan_pro_client/features/settings/domain/app_settings.dart';

void main() {
  test('initial packaging workflow reflects beta.3 release truth defaults', () {
    final store = PackagingStore();

    expect(store.state.selectedChannel, UpdateChannel.beta);
    expect(store.state.currentVersionLabel, '1.4.0-beta.3');
  });

  test('stub update check records status and timestamp', () {
    final store = PackagingStore(initialChannel: UpdateChannel.beta);

    store.runStubUpdateCheck();

    expect(store.state.lastUpdateCheckAt, isNotNull);
    expect(store.state.updateCheckStatusLabel, contains('Stub only'));
    expect(store.state.lastCheckSummary, contains('beta'));
    expect(store.state.releaseMetadataContractVersion, 'v0-draft');
  });

  test('desktop package statuses reflect packaged smoke-era readiness', () {
    final store = PackagingStore();

    final statuses = {
      for (final status in store.packageStatuses) status.platform: status,
    };

    expect(statuses[DesktopPackagePlatform.windows]?.readiness,
        DesktopPackageReadiness.scaffolded);
    expect(statuses[DesktopPackagePlatform.macos]?.readiness,
        DesktopPackageReadiness.scaffolded);
    expect(statuses[DesktopPackagePlatform.linux]?.readiness,
        DesktopPackageReadiness.validated);
    expect(
      statuses[DesktopPackagePlatform.linux]?.notes,
      contains('packaged smoke gate'),
    );
  });
}
