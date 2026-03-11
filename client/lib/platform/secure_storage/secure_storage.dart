abstract class SecureStorage {
  String get backendName;

  Future<void> writeSecret(String key, String value);

  Future<String?> readSecret(String key);

  Future<void> deleteSecret(String key);

  Future<List<String>> listKeys();
}
