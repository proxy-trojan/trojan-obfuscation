import '../../controller/domain/client_connection_status.dart';
import '../../controller/domain/failure_family.dart';
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
    required this.statusSummary,
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
  final String statusSummary;
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
          statusSummary: profileName == null
              ? 'No profile selected yet.'
              : 'Ready to connect.',
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
          statusSummary: 'Connection attempt in progress.',
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
          statusSummary: 'Runtime session is active.',
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
          statusSummary: 'Disconnect in progress.',
          activeProfileName: profileName,
          canConnect: false,
          canDisconnect: false,
          showRetry: false,
          showOpenProfiles: false,
          showOpenTroubleshooting: true,
        );
      case ClientConnectionPhase.error:
        final errorPresentation = _describeError(status.message, profileName);
        return ConnectionLifecycleViewModel(
          stage: ConnectionLifecycleStage.error,
          label: 'Needs attention',
          headline: errorPresentation.headline,
          detail: errorPresentation.detail,
          statusSummary: errorPresentation.statusSummary,
          activeProfileName: profileName,
          canConnect: errorPresentation.canRetryFromProfiles,
          canDisconnect: false,
          showRetry: errorPresentation.canRetryFromProfiles,
          showOpenProfiles: true,
          showOpenTroubleshooting: errorPresentation.showOpenTroubleshooting,
        );
    }
  }

  static _ConnectionErrorPresentation _describeError(
    String message,
    String? profileName,
  ) {
    final normalized = message.trim();
    final profileLabel = profileName ?? 'this profile';
    final family = classifyFailureFamily(
      errorCode: normalized,
      summary: normalized,
      detail: normalized,
    );

    if (family == FailureFamily.userInput) {
      return _ConnectionErrorPresentation(
        headline: '$profileLabel still needs a saved password',
        detail:
            'Open Profiles, save the Trojan password, then retry the connection test.',
        statusSummary: 'A Trojan password is still missing.',
        canRetryFromProfiles: false,
        showOpenTroubleshooting: false,
      );
    }

    if (family == FailureFamily.config) {
      return const _ConnectionErrorPresentation(
        headline: 'The runtime config needs attention',
        detail:
            'Review the selected profile and config inputs before the runtime could launch, then try again.',
        statusSummary: 'Config preparation failed before launch.',
        canRetryFromProfiles: false,
        showOpenTroubleshooting: true,
      );
    }

    if (family == FailureFamily.connect) {
      final exitCodeMatch = RegExp(r'code\s+(\d+)').firstMatch(normalized);
      if (exitCodeMatch != null) {
        final code = exitCodeMatch.group(1)!;
        return _ConnectionErrorPresentation(
          headline: 'The connection ended unexpectedly',
          detail:
              'The runtime reached launch but the connect path still failed with exit code $code. Retry from Profiles or open Troubleshooting for recent logs.',
          statusSummary: 'Connect path failed after launch (code $code).',
          canRetryFromProfiles: true,
          showOpenTroubleshooting: true,
        );
      }

      if (normalized.startsWith('Runtime session stopped with error:')) {
        final reason = normalized
            .replaceFirst('Runtime session stopped with error:', '')
            .trim();
        return _ConnectionErrorPresentation(
          headline: 'The runtime hit a local error',
          detail:
              'The current session stopped after launch and before it could stay connected. Open Troubleshooting for logs${reason.isEmpty ? '' : ' — latest detail: $reason'}.',
          statusSummary: reason.isEmpty
              ? 'Connect path failed after launch.'
              : 'Runtime error: $reason',
          canRetryFromProfiles: true,
          showOpenTroubleshooting: true,
        );
      }
    }

    if (family == FailureFamily.environment) {
      return const _ConnectionErrorPresentation(
        headline: 'This environment cannot complete that action',
        detail:
            'The current controller posture or host environment does not expose the required runtime evidence path yet.',
        statusSummary: 'Environment cannot provide the requested runtime evidence.',
        canRetryFromProfiles: false,
        showOpenTroubleshooting: true,
      );
    }

    return _ConnectionErrorPresentation(
      headline: profileName == null
          ? 'The last connection needs attention'
          : 'The last connection for $profileName needs attention',
      detail:
          'Retry from Profiles if you want to try again, or open Troubleshooting for deeper details.',
      statusSummary: normalized.isEmpty ? 'Connection failed.' : normalized,
      canRetryFromProfiles: profileName != null,
      showOpenTroubleshooting: true,
    );
  }
}

class _ConnectionErrorPresentation {
  const _ConnectionErrorPresentation({
    required this.headline,
    required this.detail,
    required this.statusSummary,
    required this.canRetryFromProfiles,
    required this.showOpenTroubleshooting,
  });

  final String headline;
  final String detail;
  final String statusSummary;
  final bool canRetryFromProfiles;
  final bool showOpenTroubleshooting;
}
