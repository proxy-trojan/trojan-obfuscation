import 'dart:io';

enum DesktopCloseBehavior {
  hideToTray,
  minimizeWindow,
  quitApplication,
}

enum DuplicateLaunchMitigation {
  none,
  fileLockSingleInstance,
}

class DesktopLifecyclePolicy {
  const DesktopLifecyclePolicy({
    required this.closeBehavior,
    required this.duplicateLaunchMitigation,
    required this.enableTrayQuickActions,
  });

  final DesktopCloseBehavior closeBehavior;
  final DuplicateLaunchMitigation duplicateLaunchMitigation;
  final bool enableTrayQuickActions;

  static const DesktopLifecyclePolicy desktopDefault = DesktopLifecyclePolicy(
    closeBehavior: DesktopCloseBehavior.hideToTray,
    duplicateLaunchMitigation: DuplicateLaunchMitigation.fileLockSingleInstance,
    enableTrayQuickActions: true,
  );

  static const DesktopLifecyclePolicy fallback = DesktopLifecyclePolicy(
    closeBehavior: DesktopCloseBehavior.quitApplication,
    duplicateLaunchMitigation: DuplicateLaunchMitigation.none,
    enableTrayQuickActions: false,
  );

  String closeSemanticsSummary({required bool trayReady}) {
    switch (closeBehavior) {
      case DesktopCloseBehavior.hideToTray:
        if (trayReady) {
          return 'Close hides the main window to tray. The app keeps running in background.';
        }
        return 'Close falls back to minimize because tray is unavailable.';
      case DesktopCloseBehavior.minimizeWindow:
        return 'Close minimizes the window to taskbar/dock. The app keeps running.';
      case DesktopCloseBehavior.quitApplication:
        return 'Close exits the app process directly.';
    }
  }

  String minimizeSemanticsSummary() {
    return 'Minimize keeps the app running and allows later restore.';
  }

  String quitSemanticsSummary() {
    return 'Quit requests a best-effort disconnect first, then exits the app.';
  }
}

class DesktopLifecycleStatus {
  const DesktopLifecycleStatus({
    required this.supported,
    required this.initialized,
    required this.trayReady,
    required this.singleInstancePrimary,
    required this.closeInterceptEnabled,
    required this.summary,
  });

  final bool supported;
  final bool initialized;
  final bool trayReady;
  final bool singleInstancePrimary;
  final bool closeInterceptEnabled;
  final String summary;

  factory DesktopLifecycleStatus.unsupported() {
    return const DesktopLifecycleStatus(
      supported: false,
      initialized: true,
      trayReady: false,
      singleInstancePrimary: true,
      closeInterceptEnabled: false,
      summary: 'Desktop lifecycle hooks are not active on this platform.',
    );
  }

  factory DesktopLifecycleStatus.initializing() {
    return const DesktopLifecycleStatus(
      supported: true,
      initialized: false,
      trayReady: false,
      singleInstancePrimary: true,
      closeInterceptEnabled: false,
      summary: 'Desktop lifecycle service is initializing.',
    );
  }

  DesktopLifecycleStatus copyWith({
    bool? supported,
    bool? initialized,
    bool? trayReady,
    bool? singleInstancePrimary,
    bool? closeInterceptEnabled,
    String? summary,
  }) {
    return DesktopLifecycleStatus(
      supported: supported ?? this.supported,
      initialized: initialized ?? this.initialized,
      trayReady: trayReady ?? this.trayReady,
      singleInstancePrimary:
          singleInstancePrimary ?? this.singleInstancePrimary,
      closeInterceptEnabled:
          closeInterceptEnabled ?? this.closeInterceptEnabled,
      summary: summary ?? this.summary,
    );
  }
}

bool isDesktopPlatform() {
  return Platform.isLinux || Platform.isMacOS || Platform.isWindows;
}
