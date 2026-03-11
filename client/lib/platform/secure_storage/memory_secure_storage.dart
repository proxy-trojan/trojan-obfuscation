import 'secure_storage.dart';

class MemorySecureStorage implements SecureStorage {
  final Map<String, String> _secrets = <String, String>{};

  @override
  String get backendName => 'memory-only-stub';

  @override
  Future<void> deleteSecret(String key) async {
    _secrets.remove(key);
  }

  @override
  Future<List<String>> listKeys() async {
    return _secrets.keys.toList()..sort();
  }

  @override
  Future<String?> readSecret(String key) async {
    return _secrets[key];
  }

  @override
  Future<void> writeSecret(String key, String value) async {
    _secrets[key] = value;
  }
}
