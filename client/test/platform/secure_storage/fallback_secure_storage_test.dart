import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/platform/secure_storage/fallback_secure_storage.dart';
import 'package:trojan_pro_client/platform/secure_storage/memory_secure_storage.dart';
import 'package:trojan_pro_client/platform/secure_storage/secure_storage.dart';

class _FlakyPrimaryStorage implements SecureStorage {
  _FlakyPrimaryStorage({this.failWrites = false, this.failReads = false});

  final Map<String, String> _values = <String, String>{};
  bool failWrites;
  bool failReads;

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
    if (failWrites) {
      throw StateError('primary delete failed');
    }
    _values.remove(key);
  }

  @override
  Future<List<String>> listKeys() async {
    if (failReads) {
      throw StateError('primary listKeys failed');
    }
    return _values.keys.toList()..sort();
  }

  @override
  Future<String?> readSecret(String key) async {
    if (failReads) {
      throw StateError('primary read failed');
    }
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

  test('deleteSecret removes from both primary and fallback', () async {
    final primary = _FlakyPrimaryStorage(failWrites: true);
    final fallback = MemorySecureStorage();
    final storage = FallbackSecureStorage(primary: primary, fallback: fallback);

    // 写入 fallback（primary 失败）
    await storage.writeSecret('key-a', 'value-a');
    expect(await fallback.readSecret('key-a'), 'value-a');

    // primary 恢复
    primary.failWrites = false;
    // 删除操作应同时清理两个后端
    await storage.deleteSecret('key-a');

    expect(await primary.readSecret('key-a'), isNull);
    expect(await fallback.readSecret('key-a'), isNull);
  });

  test('deleteSecret falls back when primary delete fails', () async {
    final primary = _FlakyPrimaryStorage(failWrites: true);
    final fallback = MemorySecureStorage();
    final storage = FallbackSecureStorage(primary: primary, fallback: fallback);

    await storage.writeSecret('key-a', 'value-a');
    // primary 删除也会失败（failWrites 同时控制 delete）
    await storage.deleteSecret('key-a');

    expect(storage.status.fallbackActive, isTrue);
    // fallback 中的数据应已被删除
    expect(await fallback.readSecret('key-a'), isNull);
  });

  test('listKeys falls back to fallback when primary fails', () async {
    final primary = _FlakyPrimaryStorage(failReads: true);
    final fallback = MemorySecureStorage();
    final storage = FallbackSecureStorage(primary: primary, fallback: fallback);

    await fallback.writeSecret('fb-key-1', 'val1');
    await fallback.writeSecret('fb-key-2', 'val2');

    // 由于 primary.listKeys 会失败，需要先触发一次 write 失败来设置 promotionNeeded
    primary.failWrites = true;
    await storage.writeSecret('trigger', 'fail');
    primary.failWrites = false;
    primary.failReads = true;

    final keys = await storage.listKeys();
    expect(keys, containsAll(<String>['fb-key-1', 'fb-key-2']));
    expect(storage.status.fallbackActive, isTrue);
  });

  test('promotion does not run when primary has never failed', () async {
    final primary = _FlakyPrimaryStorage();
    final fallback = MemorySecureStorage();
    final storage = FallbackSecureStorage(primary: primary, fallback: fallback);

    // 直接在 fallback 写入一些数据（模拟外部残留）
    await fallback.writeSecret('orphan-key', 'orphan-val');

    // 通过 storage 读取时，不应触发 promotion（因为 primary 从未失败）
    final value = await storage.readSecret('orphan-key');
    expect(value, isNull); // 从 primary 读取，primary 中没有
    // fallback 中的数据不应被迁移
    expect(await fallback.readSecret('orphan-key'), 'orphan-val');
  });

  test('primary recovery after ping-pong failure', () async {
    final primary = _FlakyPrimaryStorage(failWrites: true);
    final fallback = MemorySecureStorage();
    final storage = FallbackSecureStorage(primary: primary, fallback: fallback);

    // 第一次失败 → fallback
    await storage.writeSecret('key-1', 'val-1');
    expect(storage.status.fallbackActive, isTrue);

    // primary 恢复，promotion 成功
    primary.failWrites = false;
    final v1 = await storage.readSecret('key-1');
    expect(v1, 'val-1');
    expect(storage.status.fallbackActive, isFalse);

    // primary 再次失败
    primary.failWrites = true;
    await storage.writeSecret('key-2', 'val-2');
    expect(storage.status.fallbackActive, isTrue);
    expect(await fallback.readSecret('key-2'), 'val-2');

    // primary 恢复第二次
    primary.failWrites = false;
    final v2 = await storage.readSecret('key-2');
    expect(v2, 'val-2');
    expect(storage.status.fallbackActive, isFalse);
    expect(await fallback.listKeys(), isEmpty);
  });
}
