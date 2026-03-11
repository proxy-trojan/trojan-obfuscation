import 'dart:convert';

import 'package:flutter/material.dart';

import '../domain/app_settings.dart';

class SettingsSerialization {
  AppSettings decode(String text) {
    final decoded = jsonDecode(text) as Map<String, dynamic>;
    return AppSettings(
      themeMode: ThemeMode.values.byName((decoded['themeMode'] as String?) ?? ThemeMode.system.name),
      updateChannel: UpdateChannel.values.byName(
        (decoded['updateChannel'] as String?) ?? UpdateChannel.stable.name,
      ),
      launchOnLogin: (decoded['launchOnLogin'] as bool?) ?? false,
      collectDiagnostics: (decoded['collectDiagnostics'] as bool?) ?? true,
      diagnosticsRetentionDays: (decoded['diagnosticsRetentionDays'] as num?)?.toInt() ?? 7,
    );
  }

  String encode(AppSettings settings) {
    final payload = <String, Object?>{
      'version': 1,
      'themeMode': settings.themeMode.name,
      'updateChannel': settings.updateChannel.name,
      'launchOnLogin': settings.launchOnLogin,
      'collectDiagnostics': settings.collectDiagnostics,
      'diagnosticsRetentionDays': settings.diagnosticsRetentionDays,
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }
}
