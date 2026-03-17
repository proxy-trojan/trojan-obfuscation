import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../platform/services/local_state_store.dart';
import '../domain/client_profile.dart';
import 'profile_serialization.dart';

class ProfileStore extends ChangeNotifier {
  ProfileStore({
    List<ClientProfile>? initialProfiles,
    required LocalStateStore localStateStore,
    required ProfileSerialization serialization,
    Duration saveDebounceDuration = _defaultSaveDebounceDuration,
  })  : _localStateStore = localStateStore,
        _serialization = serialization,
        _saveDebounceDuration = saveDebounceDuration,
        _profiles = List<ClientProfile>.from(initialProfiles ?? const []),
        _selectedProfileId =
            initialProfiles != null && initialProfiles.isNotEmpty
                ? initialProfiles.first.id
                : null;

  ProfileStore.withSampleProfiles({
    required LocalStateStore localStateStore,
    required ProfileSerialization serialization,
    Duration saveDebounceDuration = _defaultSaveDebounceDuration,
  })  : _localStateStore = localStateStore,
        _serialization = serialization,
        _saveDebounceDuration = saveDebounceDuration,
        _profiles = <ClientProfile>[
          ClientProfile(
            id: 'sample-hk-1',
            name: 'Sample • Hong Kong',
            serverHost: 'hk-edge.example.com',
            serverPort: 443,
            sni: 'cdn.example.com',
            localSocksPort: 1080,
            verifyTls: true,
            notes: 'Desktop-first sample profile for shell validation.',
            updatedAt: DateTime.now(),
          ),
          ClientProfile(
            id: 'sample-us-1',
            name: 'Sample • United States',
            serverHost: 'us-edge.example.com',
            serverPort: 443,
            sni: 'assets.example.com',
            localSocksPort: 1081,
            verifyTls: true,
            notes: 'Second profile to validate switching UX.',
            updatedAt: DateTime.now(),
          ),
        ],
        _selectedProfileId = 'sample-hk-1';

  static const String _profilesKey = 'profiles.json';
  static const String _selectedProfileKey = 'profiles.selectedId';
  static const Duration _defaultSaveDebounceDuration =
      Duration(milliseconds: 300);

  final LocalStateStore _localStateStore;
  final ProfileSerialization _serialization;
  final Duration _saveDebounceDuration;
  final List<ClientProfile> _profiles;
  String? _selectedProfileId;
  bool _loaded = false;
  Timer? _saveDebounce;

  List<ClientProfile> get profiles =>
      List<ClientProfile>.unmodifiable(_profiles);

  String? get selectedProfileId => _selectedProfileId;

  bool get loaded => _loaded;

  ClientProfile? get selectedProfile {
    final selectedId = _selectedProfileId;
    if (selectedId == null) return _profiles.isEmpty ? null : _profiles.first;
    for (final profile in _profiles) {
      if (profile.id == selectedId) return profile;
    }
    return _profiles.isEmpty ? null : _profiles.first;
  }

  ClientProfile? profileById(String? id) {
    if (id == null) return null;
    for (final profile in _profiles) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  Future<void> load() async {
    final raw = await _localStateStore.read(_profilesKey);
    if (raw != null && raw.trim().isNotEmpty) {
      final profiles = _serialization.decodeProfileList(raw);
      _profiles
        ..clear()
        ..addAll(profiles);
    }

    final savedSelectedId = await _localStateStore.read(_selectedProfileKey);
    if (savedSelectedId != null &&
        savedSelectedId.trim().isNotEmpty &&
        _profiles.any((p) => p.id == savedSelectedId.trim())) {
      _selectedProfileId = savedSelectedId.trim();
    } else {
      _selectedProfileId = _profiles.isEmpty ? null : _profiles.first.id;
    }

    _loaded = true;
    notifyListeners();
  }

  Future<void> save() async {
    try {
      await _localStateStore.write(
        _profilesKey,
        _serialization.encodeProfileList(_profiles),
      );
    } catch (error) {
      debugPrint('ProfileStore: 保存配置失败: $error');
    }
  }

  Future<void> syncStoredPasswordFlags(
    Map<String, bool> flagsByProfileId,
  ) async {
    var changed = false;
    for (var i = 0; i < _profiles.length; i++) {
      final profile = _profiles[i];
      final nextHasStoredPassword = flagsByProfileId[profile.id] ?? false;
      if (profile.hasStoredPassword == nextHasStoredPassword) {
        continue;
      }
      _profiles[i] = profile.copyWith(hasStoredPassword: nextHasStoredPassword);
      changed = true;
    }
    if (!changed) return;
    _scheduleDebouncedSave();
    notifyListeners();
  }

  void selectProfile(String id) {
    if (_selectedProfileId == id) return;
    _selectedProfileId = id;
    _persistSelectedProfile();
    notifyListeners();
  }

  ClientProfile addSampleProfile() {
    final profile = ClientProfile(
      id: 'sample-${DateTime.now().microsecondsSinceEpoch}',
      name: 'New Sample Profile',
      serverHost: 'new-edge.example.com',
      serverPort: 443,
      sni: 'front.example.com',
      localSocksPort: 1080 + _profiles.length,
      verifyTls: true,
      notes: 'Created from the desktop client shell skeleton.',
      updatedAt: DateTime.now(),
    );
    _profiles.add(profile);
    _selectedProfileId = profile.id;
    _scheduleDebouncedSave();
    notifyListeners();
    return profile;
  }

  void upsertProfile(ClientProfile profile) {
    final index = _profiles.indexWhere((item) => item.id == profile.id);
    if (index == -1) {
      _profiles.add(profile);
    } else {
      _profiles[index] = profile.copyWith(updatedAt: DateTime.now());
    }
    _selectedProfileId = profile.id;
    _scheduleDebouncedSave();
    notifyListeners();
  }

  void removeSelectedProfile() {
    final selected = selectedProfile;
    if (selected == null) return;
    _profiles.removeWhere((item) => item.id == selected.id);
    _selectedProfileId = _profiles.isEmpty ? null : _profiles.first.id;
    _scheduleDebouncedSave();
    _persistSelectedProfile();
    notifyListeners();
  }

  void _persistSelectedProfile() {
    final id = _selectedProfileId;
    if (id == null) {
      _localStateStore.delete(_selectedProfileKey).catchError((error) {
        debugPrint('ProfileStore: 删除 selectedProfile 持久化失败: $error');
      });
    } else {
      _localStateStore.write(_selectedProfileKey, id).catchError((error) {
        debugPrint('ProfileStore: 保存 selectedProfile 持久化失败: $error');
      });
    }
  }

  void _scheduleDebouncedSave() {
    _saveDebounce?.cancel();
    if (_saveDebounceDuration == Duration.zero) {
      unawaited(save());
      return;
    }
    _saveDebounce = Timer(_saveDebounceDuration, () {
      unawaited(save());
    });
  }

  @visibleForTesting
  Future<void> flushPendingSave() async {
    if (_saveDebounce?.isActive ?? false) {
      _saveDebounce!.cancel();
      _saveDebounce = null;
    }
    await save();
  }

  @override
  void dispose() {
    if (_saveDebounce?.isActive ?? false) {
      _saveDebounce!.cancel();
      _saveDebounce = null;
      unawaited(save());
    }
    super.dispose();
  }
}
