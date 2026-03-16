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
}

abstract class DesktopLifecycleService extends ChangeNotifier {
  DesktopLifecyclePolicy get policy;

  DesktopLifecycleStatus get status;

  Future<void> initialize();

  Future<void> applyPolicy(DesktopLifecyclePolicy policy);

  Future<void> updateQuickActions(DesktopQuickActionsState state);

  Future<void> showMainWindow();

  Future<void> minimizeMainWindow();

  Future<void> requestQuit();

  Future<void> disposeService();
}
