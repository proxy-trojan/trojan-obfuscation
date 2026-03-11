abstract class LocalStateStore {
  String get backendName;

  Future<void> write(String key, String value);

  Future<String?> read(String key);

  Future<void> delete(String key);
}
