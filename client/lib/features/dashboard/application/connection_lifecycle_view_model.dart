import '../../controller/domain/client_connection_status.dart';
import '../../profiles/domain/client_profile.dart';

enum ConnectionLifecycleStage {
  idle,
  connecting,
  connected,
  disconnecting,
  error,
}

class ConnectionLifecycleViewModel {
  const ConnectionLifecycleViewModel({
    required this.stage,
    required this.label,
    required this.headline,
    required this.detail,
    required this.activeProfileName,
    required this.canConnect,
    required this.canDisconnect,
    required this.showRetry,
    required this.showOpenProfiles,
    required this.showOpenTroubleshooting,
  });

  final ConnectionLifecycleStage stage;
  final String label;
  final String headline;
  final String detail;
  final String? activeProfileName;
  final bool canConnect;
  final bool canDisconnect;
  final bool showRetry;
  final bool showOpenProfiles;
  final bool showOpenTroubleshooting;

  bool get isBusy =>
      stage == ConnectionLifecycleStage.connecting ||
      stage == ConnectionLifecycleStage.disconnecting;

  static ConnectionLifecycleViewModel fromStatus({
    required ClientConnectionStatus status,
    required ClientProfile? selectedProfile,
  }) {
    final profileName = selectedProfile?.name;

    switch (status.phase) {
      case ClientConnectionPhase.disconnected:
        return ConnectionLifecycleViewModel(
          stage: ConnectionLifecycleStage.idle,
          label: 'Idle',
          headline: profileName == null
              ? 'Add one profile to get started'
              : 'Ready for a connection test',
          detail: profileName == null
              ? 'Create or import one profile first.'
              : 'Select Connect when you want to test $profileName.',
          activeProfileName: profileName,
          canConnect: selectedProfile != null,
          canDisconnect: false,
          showRetry: false,
          showOpenProfiles: true,
          showOpenTroubleshooting: false,
        );
      case ClientConnectionPhase.connecting:
        return ConnectionLifecycleViewModel(
          stage: ConnectionLifecycleStage.connecting,
          label: 'Connecting',
          headline: profileName == null
              ? 'Connection attempt is running'
              : 'Connecting to $profileName',
          detail:
              'The client is establishing the runtime session. Please wait.',
          activeProfileName: profileName,
          canConnect: false,
          canDisconnect: false,
          showRetry: false,
          showOpenProfiles: false,
          showOpenTroubleshooting: true,
        );
      case ClientConnectionPhase.connected:
        return ConnectionLifecycleViewModel(
          stage: ConnectionLifecycleStage.connected,
          label: 'Connected',
          headline: profileName == null
              ? 'Connection is active'
              : 'Connected with $profileName',
          detail:
              'The runtime session is active. Disconnect before switching flows.',
          activeProfileName: profileName,
          canConnect: false,
          canDisconnect: true,
          showRetry: false,
          showOpenProfiles: true,
          showOpenTroubleshooting: true,
        );
      case ClientConnectionPhase.disconnecting:
        return ConnectionLifecycleViewModel(
          stage: ConnectionLifecycleStage.disconnecting,
          label: 'Disconnecting',
          headline: profileName == null
              ? 'Disconnect is in progress'
              : 'Disconnecting from $profileName',
          detail:
              'The current runtime session is shutting down. Please wait before reconnecting.',
          activeProfileName: profileName,
          canConnect: false,
          canDisconnect: false,
          showRetry: false,
          showOpenProfiles: false,
          showOpenTroubleshooting: true,
        );
      case ClientConnectionPhase.error:
        return ConnectionLifecycleViewModel(
          stage: ConnectionLifecycleStage.error,
          label: 'Needs attention',
          headline: profileName == null
              ? 'The last connection did not work'
              : 'The last connection for $profileName did not work',
          detail: status.message,
          activeProfileName: profileName,
          canConnect: selectedProfile != null,
          canDisconnect: false,
          showRetry: selectedProfile != null,
          showOpenProfiles: true,
          showOpenTroubleshooting: true,
        );
    }
  }
}
