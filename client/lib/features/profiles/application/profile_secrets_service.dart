import '../domain/client_profile.dart';
import '../../../platform/secure_storage/secure_storage.dart';

class ProfileSecretsSnapshot {
  const ProfileSecretsSnapshot({
    required this.profileId,
    required this.hasTrojanPassword,
  });

  final String profileId;
  final bool hasTrojanPassword;
}

class ProfileSecretsService {
  ProfileSecretsService({required SecureStorage secureStorage})
      : _secureStorage = secureStorage;

  final SecureStorage _secureStorage;

  SecureStorageStatus get storageStatus => _secureStorage.status;

  bool get isSecureStorageReady =>
      storageStatus.isSecure && storageStatus.isPersistent && !storageStatus.fallbackActive;

  String get storageSummary => storageStatus.userFacingSummary;

  Future<void> saveTrojanPassword({
    required String profileId,
    required String password,
  }) async {
    final trimmed = password.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('trojan password cannot be empty');
    }
    await _secureStorage.writeSecret(_trojanPasswordKey(profileId), trimmed);
  }

  Future<String?> readTrojanPassword(String profileId) {
    return _secureStorage.readSecret(_trojanPasswordKey(profileId));
  }

  Future<bool> hasTrojanPassword(String profileId) async {
    final value = await readTrojanPassword(profileId);
    return value != null && value.trim().isNotEmpty;
  }

  Future<void> clearTrojanPassword(String profileId) async {
    await _secureStorage.deleteSecret(_trojanPasswordKey(profileId));
  }

  Future<List<ProfileSecretsSnapshot>> snapshotForProfiles(
    Iterable<ClientProfile> profiles,
  ) async {
    final snapshots = <ProfileSecretsSnapshot>[];
    for (final profile in profiles) {
      snapshots.add(
        ProfileSecretsSnapshot(
          profileId: profile.id,
          hasTrojanPassword: await hasTrojanPassword(profile.id),
        ),
      );
    }
    return snapshots;
  }

  String _trojanPasswordKey(String profileId) =>
      'profiles.$profileId.trojan-password';
}
