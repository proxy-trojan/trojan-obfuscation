import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secure_storage.dart';

class FlutterSecureStorageAdapter implements SecureStorage {
  FlutterSecureStorageAdapter({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  String get backendName => 'flutter-secure-storage';

  @override
  Future<void> deleteSecret(String key) async {
    await _storage.delete(key: _requireKey(key));
  }

  @override
  Future<List<String>> listKeys() async {
    final all = await _storage.readAll();
    return all.keys.toList()..sort();
  }

  @override
  Future<String?> readSecret(String key) async {
    return _storage.read(key: _requireKey(key));
  }

  @override
  Future<void> writeSecret(String key, String value) async {
    await _storage.write(key: _requireKey(key), value: value);
  }

  String _requireKey(String key) {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('secure storage key cannot be empty');
    }
    return trimmed;
  }
}
