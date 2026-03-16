import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/settings/application/settings_serialization.dart';
import 'package:trojan_pro_client/features/settings/domain/app_settings.dart';
import 'package:trojan_pro_client/platform/services/desktop_lifecycle_models.dart';

void main() {
  final serialization = SettingsSerialization();

  test('decode falls back to hideToTray when desktop close field is missing',
      () {
    final raw = jsonEncode(<String, Object?>{
      'themeMode': ThemeMode.system.name,
      'updateChannel': UpdateChannel.stable.name,
      'autoCheckForUpdates': true,
      'launchOnLogin': false,
      'collectDiagnostics': true,
      'diagnosticsRetentionDays': 7,
    });

    final settings = serialization.decode(raw);
    expect(settings.desktopCloseBehavior, DesktopCloseBehavior.hideToTray);
  });

  test('encode stores desktop close behavior value', () {
    const settings = AppSettings(
      themeMode: ThemeMode.dark,
      updateChannel: UpdateChannel.beta,
      autoCheckForUpdates: false,
      launchOnLogin: true,
      desktopCloseBehavior: DesktopCloseBehavior.minimizeWindow,
      collectDiagnostics: true,
      diagnosticsRetentionDays: 14,
    );

    final encoded = serialization.encode(settings);
    final decoded = jsonDecode(encoded) as Map<String, dynamic>;
    expect(decoded['desktopCloseBehavior'], 'minimizeWindow');
  });
}
