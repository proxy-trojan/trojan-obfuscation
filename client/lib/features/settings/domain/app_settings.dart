import 'package:flutter/material.dart';

enum UpdateChannel {
  stable,
  beta,
  nightly,
}

class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.updateChannel,
    required this.launchOnLogin,
    required this.collectDiagnostics,
    required this.diagnosticsRetentionDays,
  });

  final ThemeMode themeMode;
  final UpdateChannel updateChannel;
  final bool launchOnLogin;
  final bool collectDiagnostics;
  final int diagnosticsRetentionDays;

  AppSettings copyWith({
    ThemeMode? themeMode,
    UpdateChannel? updateChannel,
    bool? launchOnLogin,
    bool? collectDiagnostics,
    int? diagnosticsRetentionDays,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      updateChannel: updateChannel ?? this.updateChannel,
      launchOnLogin: launchOnLogin ?? this.launchOnLogin,
      collectDiagnostics: collectDiagnostics ?? this.collectDiagnostics,
      diagnosticsRetentionDays:
          diagnosticsRetentionDays ?? this.diagnosticsRetentionDays,
    );
  }

  static const AppSettings defaults = AppSettings(
    themeMode: ThemeMode.system,
    updateChannel: UpdateChannel.stable,
    launchOnLogin: false,
    collectDiagnostics: true,
    diagnosticsRetentionDays: 7,
  );
}
