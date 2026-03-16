import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/packaging/application/packaging_store.dart';
import 'package:trojan_pro_client/features/settings/domain/app_settings.dart';

void main() {
  test('stub update check records status and timestamp', () {
    final store = PackagingStore(initialChannel: UpdateChannel.beta);

    store.runStubUpdateCheck();

    expect(store.state.lastUpdateCheckAt, isNotNull);
    expect(store.state.updateCheckStatusLabel, contains('Stub only'));
    expect(store.state.lastCheckSummary, contains('beta'));
    expect(store.state.releaseMetadataContractVersion, 'v0-draft');
  });
}
