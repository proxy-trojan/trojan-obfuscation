import 'package:flutter/material.dart';

import '../../../platform/services/desktop_lifecycle_models.dart';

enum UpdateChannel {
  stable,
  beta,
  nightly,
}

class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.updateChannel,
    required this.autoCheckForUpdates,
    required this.launchOnLogin,
    required this.desktopCloseBehavior,
    required this.collectDiagnostics,
    required this.diagnosticsRetentionDays,
  });

  final ThemeMode themeMode;
  final UpdateChannel updateChannel;
  final bool autoCheckForUpdates;
  final bool launchOnLogin;
  final DesktopCloseBehavior desktopCloseBehavior;
  final bool collectDiagnostics;
  final int diagnosticsRetentionDays;

  AppSettings copyWith({
    ThemeMode? themeMode,
    UpdateChannel? updateChannel,
    bool? autoCheckForUpdates,
    bool? launchOnLogin,
    DesktopCloseBehavior? desktopCloseBehavior,
    bool? collectDiagnostics,
    int? diagnosticsRetentionDays,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      updateChannel: updateChannel ?? this.updateChannel,
      autoCheckForUpdates: autoCheckForUpdates ?? this.autoCheckForUpdates,
      launchOnLogin: launchOnLogin ?? this.launchOnLogin,
      desktopCloseBehavior: desktopCloseBehavior ?? this.desktopCloseBehavior,
      collectDiagnostics: collectDiagnostics ?? this.collectDiagnostics,
      diagnosticsRetentionDays:
          diagnosticsRetentionDays ?? this.diagnosticsRetentionDays,
    );
  }

  static const AppSettings defaults = AppSettings(
    themeMode: ThemeMode.system,
    updateChannel: UpdateChannel.stable,
    autoCheckForUpdates: true,
    launchOnLogin: false,
    desktopCloseBehavior: DesktopCloseBehavior.hideToTray,
    collectDiagnostics: true,
    diagnosticsRetentionDays: 7,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          runtimeType == other.runtimeType &&
          themeMode == other.themeMode &&
          updateChannel == other.updateChannel &&
          autoCheckForUpdates == other.autoCheckForUpdates &&
          launchOnLogin == other.launchOnLogin &&
          desktopCloseBehavior == other.desktopCloseBehavior &&
          collectDiagnostics == other.collectDiagnostics &&
          diagnosticsRetentionDays == other.diagnosticsRetentionDays;

  @override
  int get hashCode => Object.hash(
        themeMode,
        updateChannel,
        autoCheckForUpdates,
        launchOnLogin,
        desktopCloseBehavior,
        collectDiagnostics,
        diagnosticsRetentionDays,
      );
}
