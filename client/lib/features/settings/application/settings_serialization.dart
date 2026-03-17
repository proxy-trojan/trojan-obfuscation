import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../platform/services/desktop_lifecycle_models.dart';
import '../domain/app_settings.dart';

class SettingsSerialization {
  /// 安全地将字符串解析为枚举值，未匹配时返回 [fallback]。
  static T _safeEnum<T extends Enum>(List<T> values, String? name, T fallback) {
    if (name == null) return fallback;
    return values.asNameMap()[name] ?? fallback;
  }

  AppSettings decode(String text) {
    final decoded = jsonDecode(text) as Map<String, dynamic>;
    return AppSettings(
      themeMode: _safeEnum(
        ThemeMode.values,
        decoded['themeMode'] as String?,
        ThemeMode.system,
      ),
      updateChannel: _safeEnum(
        UpdateChannel.values,
        decoded['updateChannel'] as String?,
        UpdateChannel.stable,
      ),
      autoCheckForUpdates: (decoded['autoCheckForUpdates'] as bool?) ?? true,
      launchOnLogin: (decoded['launchOnLogin'] as bool?) ?? false,
      desktopCloseBehavior: _safeEnum(
        DesktopCloseBehavior.values,
        decoded['desktopCloseBehavior'] as String?,
        DesktopCloseBehavior.hideToTray,
      ),
      collectDiagnostics: (decoded['collectDiagnostics'] as bool?) ?? true,
      diagnosticsRetentionDays:
          (decoded['diagnosticsRetentionDays'] as num?)?.toInt() ?? 7,
    );
  }

  String encode(AppSettings settings) {
    final payload = <String, Object?>{
      'version': 1,
      'themeMode': settings.themeMode.name,
      'updateChannel': settings.updateChannel.name,
      'autoCheckForUpdates': settings.autoCheckForUpdates,
      'launchOnLogin': settings.launchOnLogin,
      'desktopCloseBehavior': settings.desktopCloseBehavior.name,
      'collectDiagnostics': settings.collectDiagnostics,
      'diagnosticsRetentionDays': settings.diagnosticsRetentionDays,
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }
}
