class SecureStorageStatus {
  const SecureStorageStatus({
    required this.backendName,
    required this.activeBackendName,
    required this.isSecure,
    required this.isPersistent,
    this.fallbackEnabled = false,
    this.fallbackActive = false,
    this.primaryBackendName,
    this.fallbackBackendName,
    this.lastPrimaryError,
  });

  final String backendName;
  final String activeBackendName;
  final bool isSecure;
  final bool isPersistent;
  final bool fallbackEnabled;
  final bool fallbackActive;
  final String? primaryBackendName;
  final String? fallbackBackendName;
  final String? lastPrimaryError;

  String get storageModeLabel {
    if (isSecure && isPersistent) return 'Secure persistent';
    if (isPersistent) return 'Persistent';
    return 'Session-only';
  }

  String get userFacingSummary {
    if (fallbackActive && !isPersistent) {
      return 'Temporary session-only fallback';
    }
    if (!isPersistent) {
      return 'Session-only storage';
    }
    if (fallbackActive) {
      return 'Fallback active';
    }
    if (isSecure && isPersistent) {
      return 'Secure storage ready';
    }
    return 'Storage available';
  }
}

abstract class SecureStorage {
  SecureStorageStatus get status;

  String get backendName;

  Future<void> writeSecret(String key, String value);

  Future<String?> readSecret(String key);

  Future<void> deleteSecret(String key);

  Future<List<String>> listKeys();
}
