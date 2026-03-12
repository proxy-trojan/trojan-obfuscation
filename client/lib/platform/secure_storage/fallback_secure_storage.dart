import 'secure_storage.dart';

class FallbackSecureStorage implements SecureStorage {
  FallbackSecureStorage({
    required SecureStorage primary,
    required SecureStorage fallback,
  })  : _primary = primary,
        _fallback = fallback;

  final SecureStorage _primary;
  final SecureStorage _fallback;

  @override
  String get backendName => '${_primary.backendName}|fallback:${_fallback.backendName}';

  @override
  Future<void> deleteSecret(String key) async {
    try {
      await _primary.deleteSecret(key);
    } catch (_) {
      await _fallback.deleteSecret(key);
    }
  }

  @override
  Future<List<String>> listKeys() async {
    try {
      return await _primary.listKeys();
    } catch (_) {
      return _fallback.listKeys();
    }
  }

  @override
  Future<String?> readSecret(String key) async {
    try {
      return await _primary.readSecret(key);
    } catch (_) {
      return _fallback.readSecret(key);
    }
  }

  @override
  Future<void> writeSecret(String key, String value) async {
    try {
      await _primary.writeSecret(key, value);
    } catch (_) {
      await _fallback.writeSecret(key, value);
    }
  }
}
