import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/platform/secure_storage/fallback_secure_storage.dart';
import 'package:trojan_pro_client/platform/secure_storage/memory_secure_storage.dart';
import 'package:trojan_pro_client/platform/secure_storage/secure_storage.dart';

class _FlakyPrimaryStorage implements SecureStorage {
  _FlakyPrimaryStorage({this.failWrites = false});

  final Map<String, String> _values = <String, String>{};
  bool failWrites;

  @override
  String get backendName => 'flaky-primary';

  @override
  SecureStorageStatus get status => const SecureStorageStatus(
        backendName: 'flaky-primary',
        activeBackendName: 'flaky-primary',
        isSecure: true,
        isPersistent: true,
      );

  @override
  Future<void> deleteSecret(String key) async {
    _values.remove(key);
  }

  @override
  Future<List<String>> listKeys() async => _values.keys.toList()..sort();

  @override
  Future<String?> readSecret(String key) async {
    return _values[key];
  }

  @override
  Future<void> writeSecret(String key, String value) async {
    if (failWrites) {
      throw StateError('primary write failed');
    }
    _values[key] = value;
  }
}

void main() {
  test('falls back to memory storage when primary write fails', () async {
    final primary = _FlakyPrimaryStorage(failWrites: true);
    final fallback = MemorySecureStorage();
    final storage = FallbackSecureStorage(primary: primary, fallback: fallback);

    await storage.writeSecret('profiles.demo.trojan-password', 'secret');

    expect(storage.status.fallbackActive, isTrue);
    expect(storage.status.isPersistent, isFalse);
    expect(await fallback.readSecret('profiles.demo.trojan-password'), 'secret');
  });

  test('promotes fallback secrets back to primary once healthy again', () async {
    final primary = _FlakyPrimaryStorage(failWrites: true);
    final fallback = MemorySecureStorage();
    final storage = FallbackSecureStorage(primary: primary, fallback: fallback);

    await storage.writeSecret('profiles.demo.trojan-password', 'secret');
    expect(storage.status.fallbackActive, isTrue);

    primary.failWrites = false;
    final value = await storage.readSecret('profiles.demo.trojan-password');

    expect(value, 'secret');
    expect(storage.status.fallbackActive, isFalse);
    expect(storage.status.isPersistent, isTrue);
    expect(await primary.readSecret('profiles.demo.trojan-password'), 'secret');
    expect(await fallback.listKeys(), isEmpty);
  });
}
