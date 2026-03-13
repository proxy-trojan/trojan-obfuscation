import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/controller/domain/client_connection_status.dart';
import 'package:trojan_pro_client/features/dashboard/application/connection_lifecycle_view_model.dart';
import 'package:trojan_pro_client/features/profiles/domain/client_profile.dart';

final _fixedTime = DateTime.parse('2026-03-13T00:00:00.000Z');

ClientProfile _profile() => ClientProfile(
      id: 'profile-1',
      name: 'HK Edge',
      serverHost: 'example.com',
      serverPort: 443,
      sni: 'example.com',
      localSocksPort: 1080,
      verifyTls: true,
      updatedAt: _fixedTime,
      hasStoredPassword: true,
    );

void main() {
  test('maps disconnected status to idle stage', () {
    final model = ConnectionLifecycleViewModel.fromStatus(
      status: ClientConnectionStatus.disconnected(),
      selectedProfile: _profile(),
    );

    expect(model.stage, ConnectionLifecycleStage.idle);
    expect(model.label, 'Idle');
    expect(model.canConnect, isTrue);
    expect(model.canDisconnect, isFalse);
  });

  test('maps disconnecting status to disconnecting stage', () {
    final model = ConnectionLifecycleViewModel.fromStatus(
      status: ClientConnectionStatus(
        phase: ClientConnectionPhase.disconnecting,
        message: 'Disconnecting current session...',
        updatedAt: _fixedTime,
        activeProfileId: 'profile-1',
      ),
      selectedProfile: _profile(),
    );

    expect(model.stage, ConnectionLifecycleStage.disconnecting);
    expect(model.label, 'Disconnecting');
    expect(model.isBusy, isTrue);
    expect(model.canConnect, isFalse);
    expect(model.showOpenTroubleshooting, isTrue);
  });

  test('maps error status to retry-capable model', () {
    final model = ConnectionLifecycleViewModel.fromStatus(
      status: ClientConnectionStatus(
        phase: ClientConnectionPhase.error,
        message: 'Runtime exited with code 7.',
        updatedAt: _fixedTime,
        activeProfileId: 'profile-1',
      ),
      selectedProfile: _profile(),
    );

    expect(model.stage, ConnectionLifecycleStage.error);
    expect(model.showRetry, isTrue);
    expect(model.canConnect, isTrue);
  });
}
