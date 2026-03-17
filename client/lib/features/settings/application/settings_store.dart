import 'dart:async';

import 'package:flutter/material.dart';

import '../../../platform/services/desktop_lifecycle_models.dart';
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
  static const Duration _saveDebounceDuration = Duration(milliseconds: 300);

  final LocalStateStore _localStateStore;
  final SettingsSerialization _serialization;
  AppSettings _settings = AppSettings.defaults;
  bool _loaded = false;
  Timer? _saveDebounce;

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
    try {
      await _localStateStore.write(
          _settingsKey, _serialization.encode(_settings));
    } catch (error) {
      debugPrint('SettingsStore: 保存设置失败: $error');
      // 尽力持久化：保存失败不阻塞 UI 交互
    }
  }

  /// 更新设置字段并触发防抖持久化 + UI 通知。
  void _updateAndSave(AppSettings Function(AppSettings current) updater) {
    final previous = _settings;
    _settings = updater(_settings);
    if (_settings == previous) return;
    _scheduleDebouncedSave();
    notifyListeners();
  }

  void _scheduleDebouncedSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(_saveDebounceDuration, () {
      unawaited(save());
    });
  }

  void setThemeMode(ThemeMode value) {
    _updateAndSave((s) => s.copyWith(themeMode: value));
  }

  void setUpdateChannel(UpdateChannel value) {
    _updateAndSave((s) => s.copyWith(updateChannel: value));
  }

  void setAutoCheckForUpdates(bool value) {
    _updateAndSave((s) => s.copyWith(autoCheckForUpdates: value));
  }

  void setLaunchOnLogin(bool value) {
    _updateAndSave((s) => s.copyWith(launchOnLogin: value));
  }

  void setDesktopCloseBehavior(DesktopCloseBehavior value) {
    _updateAndSave((s) => s.copyWith(desktopCloseBehavior: value));
  }

  void setCollectDiagnostics(bool value) {
    _updateAndSave((s) => s.copyWith(collectDiagnostics: value));
  }

  void setDiagnosticsRetentionDays(int value) {
    _updateAndSave((s) => s.copyWith(diagnosticsRetentionDays: value));
  }

  @override
  void dispose() {
    if (_saveDebounce?.isActive ?? false) {
      _saveDebounce!.cancel();
      unawaited(save()); // 确保 pending 的数据不丢失
    }
    super.dispose();
  }
}
