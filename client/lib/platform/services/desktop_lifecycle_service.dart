import 'package:flutter/foundation.dart';

import 'desktop_lifecycle_models.dart';

typedef DesktopQuitHandler = Future<void> Function();
typedef DesktopConnectHandler = Future<void> Function();
typedef DesktopDisconnectHandler = Future<void> Function();

class DesktopQuickActionsState {
  const DesktopQuickActionsState({
    required this.hasSelectedProfile,
    required this.selectedProfileName,
    required this.canConnect,
    required this.canDisconnect,
  });

  final bool hasSelectedProfile;
  final String? selectedProfileName;
  final bool canConnect;
  final bool canDisconnect;

  static const DesktopQuickActionsState initial = DesktopQuickActionsState(
    hasSelectedProfile: false,
    selectedProfileName: null,
    canConnect: false,
    canDisconnect: false,
  );

  String profileSummary() {
    final selectedProfileName = this.selectedProfileName;
    if (!hasSelectedProfile ||
        selectedProfileName == null ||
        selectedProfileName.trim().isEmpty) {
      return 'No profile is currently selected for tray quick actions.';
    }
    return 'Selected quick-action profile: $selectedProfileName';
  }

  String readinessSummary({required bool trayReady}) {
    if (!trayReady) {
      return 'Tray quick actions are unavailable because tray integration is not active on this platform/runtime.';
    }
    if (canDisconnect) {
      return 'Tray quick actions are ready to disconnect the active runtime session.';
    }
    if (canConnect) {
      return 'Tray quick actions are ready to connect the selected profile.';
    }
    if (!hasSelectedProfile) {
      return 'Tray quick actions are available, but no profile is selected yet.';
    }
    return 'Tray quick actions are available, but runtime actions are waiting for a stable session state.';
  }
}

abstract class DesktopLifecycleService extends ChangeNotifier {
  DesktopLifecyclePolicy get policy;

  DesktopLifecycleStatus get status;

  DesktopQuickActionsState get quickActions;

  Future<void> initialize();

  Future<void> applyPolicy(DesktopLifecyclePolicy policy);

  Future<void> updateQuickActions(DesktopQuickActionsState state);

  Future<void> recordExternalActivation({required String source});

  Future<void> clearExternalActivation();

  Future<void> showMainWindow();

  Future<void> minimizeMainWindow();

  Future<void> requestQuit();

  Future<void> disposeService();
}
