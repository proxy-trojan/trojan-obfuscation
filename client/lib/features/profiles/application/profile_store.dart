import 'package:flutter/foundation.dart';

import '../domain/client_profile.dart';

class ProfileStore extends ChangeNotifier {
  ProfileStore({List<ClientProfile>? initialProfiles})
      : _profiles = List<ClientProfile>.from(initialProfiles ?? const []),
        _selectedProfileId =
            initialProfiles != null && initialProfiles.isNotEmpty ? initialProfiles.first.id : null;

  ProfileStore.withSampleProfiles()
      : _profiles = <ClientProfile>[
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

  final List<ClientProfile> _profiles;
  String? _selectedProfileId;

  List<ClientProfile> get profiles => List<ClientProfile>.unmodifiable(_profiles);

  String? get selectedProfileId => _selectedProfileId;

  ClientProfile? get selectedProfile {
    final selectedId = _selectedProfileId;
    if (selectedId == null) return _profiles.isEmpty ? null : _profiles.first;
    for (final profile in _profiles) {
      if (profile.id == selectedId) return profile;
    }
    return _profiles.isEmpty ? null : _profiles.first;
  }

  void selectProfile(String id) {
    if (_selectedProfileId == id) return;
    _selectedProfileId = id;
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
    notifyListeners();
  }

  void removeSelectedProfile() {
    final selected = selectedProfile;
    if (selected == null) return;
    _profiles.removeWhere((item) => item.id == selected.id);
    _selectedProfileId = _profiles.isEmpty ? null : _profiles.first.id;
    notifyListeners();
  }
}
