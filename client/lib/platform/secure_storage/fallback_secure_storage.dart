import 'secure_storage.dart';

class FallbackSecureStorage implements SecureStorage {
  FallbackSecureStorage({
    required SecureStorage primary,
    required SecureStorage fallback,
  })  : _primary = primary,
        _fallback = fallback,
        _status = SecureStorageStatus(
          backendName: '${primary.backendName}|fallback:${fallback.backendName}',
          activeBackendName: primary.status.activeBackendName,
          isSecure: primary.status.isSecure,
          isPersistent: primary.status.isPersistent,
          fallbackEnabled: true,
          fallbackActive: false,
          primaryBackendName: primary.status.activeBackendName,
          fallbackBackendName: fallback.status.activeBackendName,
        );

  final SecureStorage _primary;
  final SecureStorage _fallback;
  SecureStorageStatus _status;

  @override
  String get backendName => '${_primary.backendName}|fallback:${_fallback.backendName}';

  @override
  SecureStorageStatus get status => _status;

  @override
  Future<void> deleteSecret(String key) async {
    await _attemptFallbackPromotion();
    try {
      await _primary.deleteSecret(key);
      _markPrimaryHealthy();
    } catch (error) {
      _markPrimaryFailed(error);
      await _fallback.deleteSecret(key);
    }
  }

  @override
  Future<List<String>> listKeys() async {
    await _attemptFallbackPromotion();
    try {
      final keys = await _primary.listKeys();
      _markPrimaryHealthy();
      return keys;
    } catch (error) {
      _markPrimaryFailed(error);
      return _fallback.listKeys();
    }
  }

  @override
  Future<String?> readSecret(String key) async {
    await _attemptFallbackPromotion();
    try {
      final value = await _primary.readSecret(key);
      _markPrimaryHealthy();
      return value;
    } catch (error) {
      _markPrimaryFailed(error);
      return _fallback.readSecret(key);
    }
  }

  @override
  Future<void> writeSecret(String key, String value) async {
    await _attemptFallbackPromotion();
    try {
      await _primary.writeSecret(key, value);
      _markPrimaryHealthy();
    } catch (error) {
      _markPrimaryFailed(error);
      await _fallback.writeSecret(key, value);
    }
  }

  Future<void> _attemptFallbackPromotion() async {
    final fallbackKeys = await _fallback.listKeys();
    if (fallbackKeys.isEmpty) return;

    try {
      for (final key in fallbackKeys) {
        final value = await _fallback.readSecret(key);
        if (value == null) continue;
        await _primary.writeSecret(key, value);
      }
      for (final key in fallbackKeys) {
        await _fallback.deleteSecret(key);
      }
      _markPrimaryHealthy();
    } catch (error) {
      _markPrimaryFailed(error);
    }
  }

  void _markPrimaryHealthy() {
    _status = SecureStorageStatus(
      backendName: '${_primary.backendName}|fallback:${_fallback.backendName}',
      activeBackendName: _primary.status.activeBackendName,
      isSecure: _primary.status.isSecure,
      isPersistent: _primary.status.isPersistent,
      fallbackEnabled: true,
      fallbackActive: false,
      primaryBackendName: _primary.status.activeBackendName,
      fallbackBackendName: _fallback.status.activeBackendName,
    );
  }

  void _markPrimaryFailed(Object error) {
    _status = SecureStorageStatus(
      backendName: '${_primary.backendName}|fallback:${_fallback.backendName}',
      activeBackendName: _fallback.status.activeBackendName,
      isSecure: _fallback.status.isSecure,
      isPersistent: _fallback.status.isPersistent,
      fallbackEnabled: true,
      fallbackActive: true,
      primaryBackendName: _primary.status.activeBackendName,
      fallbackBackendName: _fallback.status.activeBackendName,
      lastPrimaryError: '${error.runtimeType}: $error',
    );
  }
}
