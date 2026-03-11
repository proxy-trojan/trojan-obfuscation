import '../../profiles/domain/client_profile.dart';
import '../domain/client_connection_status.dart';
import 'client_controller_api.dart';

class FakeClientController extends ClientControllerApi {
  ClientConnectionStatus _status = ClientConnectionStatus.disconnected();

  @override
  ClientConnectionStatus get status => _status;

  @override
  Future<void> connect(ClientProfile profile) async {
    _status = ClientConnectionStatus(
      phase: ClientConnectionPhase.connecting,
      message: 'Resolving ${profile.serverHost}...',
      updatedAt: DateTime.now(),
      activeProfileId: profile.id,
    );
    notifyListeners();

    await Future<void>.delayed(const Duration(milliseconds: 350));

    _status = _status.copyWith(
      phase: ClientConnectionPhase.connecting,
      message: 'Establishing secure session for ${profile.name}...',
      updatedAt: DateTime.now(),
    );
    notifyListeners();

    await Future<void>.delayed(const Duration(milliseconds: 450));

    _status = ClientConnectionStatus(
      phase: ClientConnectionPhase.connected,
      message: 'Connected via fake controller boundary',
      updatedAt: DateTime.now(),
      activeProfileId: profile.id,
    );
    notifyListeners();
  }

  @override
  Future<void> disconnect() async {
    _status = ClientConnectionStatus.disconnected();
    notifyListeners();
  }
}
