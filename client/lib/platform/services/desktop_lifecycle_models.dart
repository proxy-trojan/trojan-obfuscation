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

  DesktopLifecyclePolicy copyWith({
    DesktopCloseBehavior? closeBehavior,
    DuplicateLaunchMitigation? duplicateLaunchMitigation,
    bool? enableTrayQuickActions,
  }) {
    return DesktopLifecyclePolicy(
      closeBehavior: closeBehavior ?? this.closeBehavior,
      duplicateLaunchMitigation:
          duplicateLaunchMitigation ?? this.duplicateLaunchMitigation,
      enableTrayQuickActions:
          enableTrayQuickActions ?? this.enableTrayQuickActions,
    );
  }

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

  String duplicateLaunchSummary({required bool singleInstancePrimary}) {
    switch (duplicateLaunchMitigation) {
      case DuplicateLaunchMitigation.none:
        return 'Duplicate launch mitigation is disabled; multiple windows/processes may appear.';
      case DuplicateLaunchMitigation.fileLockSingleInstance:
        return singleInstancePrimary
            ? 'Duplicate launch mitigation uses a file-lock guard; a second launch should focus the existing window and exit.'
            : 'This process is not the primary desktop instance and should hand focus back to the existing window.';
    }
  }

  String trayPolicySummary() {
    if (!enableTrayQuickActions) {
      return 'Tray quick actions are disabled by policy.';
    }
    return 'Tray quick actions should expose Open / Connect / Disconnect / Quit when tray support is available.';
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
    this.lastExternalActivationAt,
    this.lastExternalActivationSource,
  });

  final bool supported;
  final bool initialized;
  final bool trayReady;
  final bool singleInstancePrimary;
  final bool closeInterceptEnabled;
  final String summary;
  final DateTime? lastExternalActivationAt;
  final String? lastExternalActivationSource;

  factory DesktopLifecycleStatus.unsupported() {
    return const DesktopLifecycleStatus(
      supported: false,
      initialized: true,
      trayReady: false,
      singleInstancePrimary: true,
      closeInterceptEnabled: false,
      summary: 'Desktop lifecycle hooks are not active on this platform.',
      lastExternalActivationAt: null,
      lastExternalActivationSource: null,
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
      lastExternalActivationAt: null,
      lastExternalActivationSource: null,
    );
  }

  bool get hasExternalActivation {
    final source = lastExternalActivationSource;
    return lastExternalActivationAt != null &&
        source != null &&
        source.trim().isNotEmpty;
  }

  bool isRecentExternalActivation({
    Duration maxAge = const Duration(minutes: 5),
    DateTime? now,
  }) {
    final activatedAt = lastExternalActivationAt;
    if (!hasExternalActivation || activatedAt == null) {
      return false;
    }
    final currentTime = now ?? DateTime.now();
    return currentTime.difference(activatedAt) <= maxAge;
  }

  String externalActivationHeadline() {
    final source = lastExternalActivationSource;
    if (!hasExternalActivation || source == null) {
      return 'No recent external activation';
    }
    switch (source) {
      case 'secondary-launch-focus-ipc':
        return 'Another launch focused this existing window';
      default:
        return 'The desktop window was activated externally';
    }
  }

  String externalActivationGuidance() {
    final source = lastExternalActivationSource;
    if (!hasExternalActivation || source == null) {
      return 'No external activation has been observed in this app session.';
    }
    switch (source) {
      case 'secondary-launch-focus-ipc':
        return 'Single-instance mitigation is working: a second app launch handed focus back to the existing window instead of opening a duplicate session.';
      default:
        return 'The current app session received an external activation signal.';
    }
  }

  String externalActivationSummary() {
    final activatedAt = lastExternalActivationAt;
    final source = lastExternalActivationSource;
    if (activatedAt == null || source == null || source.trim().isEmpty) {
      return 'No external activation has been observed in this app session.';
    }
    return 'Last external activation came from $source at ${activatedAt.toIso8601String()}.';
  }

  DesktopLifecycleStatus copyWith({
    bool? supported,
    bool? initialized,
    bool? trayReady,
    bool? singleInstancePrimary,
    bool? closeInterceptEnabled,
    String? summary,
    DateTime? lastExternalActivationAt,
    String? lastExternalActivationSource,
    bool clearLastExternalActivation = false,
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
      lastExternalActivationAt: clearLastExternalActivation
          ? null
          : (lastExternalActivationAt ?? this.lastExternalActivationAt),
      lastExternalActivationSource: clearLastExternalActivation
          ? null
          : (lastExternalActivationSource ?? this.lastExternalActivationSource),
    );
  }
}

bool isDesktopPlatform() {
  return Platform.isLinux || Platform.isMacOS || Platform.isWindows;
}
