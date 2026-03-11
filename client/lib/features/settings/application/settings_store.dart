import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../platform/services/local_state_store.dart';
import '../domain/app_settings.dart';
import 'settings_serialization.dart';

class SettingsStore extends ChangeNotifier {
  SettingsStore({
    required LocalStateStore localStateStore,
    required SettingsSerialization serialization,
  })  : _localStateStore = localStateStore,
        _serialization = serialization;

  static const String _settingsKey = 'settings.json';

  final LocalStateStore _localStateStore;
  final SettingsSerialization _serialization;
  AppSettings _settings = AppSettings.defaults;
  bool _loaded = false;

  AppSettings get settings => _settings;

  bool get loaded => _loaded;

  Future<void> load() async {
    final raw = await _localStateStore.read(_settingsKey);
    if (raw != null && raw.trim().isNotEmpty) {
      _settings = _serialization.decode(raw);
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> save() async {
    await _localStateStore.write(_settingsKey, _serialization.encode(_settings));
  }

  void setThemeMode(ThemeMode value) {
    _settings = _settings.copyWith(themeMode: value);
    save();
    notifyListeners();
  }

  void setUpdateChannel(UpdateChannel value) {
    _settings = _settings.copyWith(updateChannel: value);
    save();
    notifyListeners();
  }

  void setLaunchOnLogin(bool value) {
    _settings = _settings.copyWith(launchOnLogin: value);
    save();
    notifyListeners();
  }

  void setCollectDiagnostics(bool value) {
    _settings = _settings.copyWith(collectDiagnostics: value);
    save();
    notifyListeners();
  }

  void setDiagnosticsRetentionDays(int value) {
    _settings = _settings.copyWith(diagnosticsRetentionDays: value);
    save();
    notifyListeners();
  }
}
