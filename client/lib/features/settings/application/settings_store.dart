import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../domain/app_settings.dart';

class SettingsStore extends ChangeNotifier {
  AppSettings _settings = AppSettings.defaults;

  AppSettings get settings => _settings;

  void setThemeMode(ThemeMode value) {
    _settings = _settings.copyWith(themeMode: value);
    notifyListeners();
  }

  void setUpdateChannel(UpdateChannel value) {
    _settings = _settings.copyWith(updateChannel: value);
    notifyListeners();
  }

  void setLaunchOnLogin(bool value) {
    _settings = _settings.copyWith(launchOnLogin: value);
    notifyListeners();
  }

  void setCollectDiagnostics(bool value) {
    _settings = _settings.copyWith(collectDiagnostics: value);
    notifyListeners();
  }

  void setDiagnosticsRetentionDays(int value) {
    _settings = _settings.copyWith(diagnosticsRetentionDays: value);
    notifyListeners();
  }
}
