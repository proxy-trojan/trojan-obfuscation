import 'dart:async';

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

  /// 防止并发 promotion 的互斥锁
  Completer<void>? _promotionLock;

  /// 仅在 primary 失败后设为 true，避免每次操作都触发全量迁移
  bool _promotionNeeded = false;

  @override
  String get backendName => '${_primary.backendName}|fallback:${_fallback.backendName}';

  @override
  SecureStorageStatus get status => _status;

  @override
  Future<void> deleteSecret(String key) async {
    // delete 不应先 promotion，否则会把准备删除的密钥重新复制回 primary。
    // 这里直接双端删除，优先保证“删干净”而不是“先迁移再删”。
    final errors = <Object>[];
    try {
      await _primary.deleteSecret(key);
    } catch (error) {
      errors.add(error);
    }
    try {
      await _fallback.deleteSecret(key);
    } catch (_) {
      // fallback 删除失败可忽略（可能本来就不存在）
    }
    if (errors.isNotEmpty) {
      _markPrimaryFailed(errors.first);
    } else {
      _markPrimaryHealthy();
    }
  }

  @override
  Future<List<String>> listKeys() async {
    await _attemptFallbackPromotion();
    try {
      final keys = await _primary.listKeys();
      await _finalizeFallbackPromotion();
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
      await _finalizeFallbackPromotion();
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
      await _finalizeFallbackPromotion();
      _markPrimaryHealthy();
    } catch (error) {
      _markPrimaryFailed(error);
      await _fallback.writeSecret(key, value);
    }
  }

  Future<void> _attemptFallbackPromotion() async {
    // 仅在 primary 曾经失败后才尝试 promotion
    if (!_promotionNeeded) return;

    // 通过 Completer 互斥，避免并发 promotion
    if (_promotionLock != null) {
      await _promotionLock!.future;
      return;
    }
    _promotionLock = Completer<void>();

    try {
      final fallbackKeys = await _fallback.listKeys();
      if (fallbackKeys.isEmpty) {
        _promotionNeeded = false;
        return;
      }

      for (final key in fallbackKeys) {
        final value = await _fallback.readSecret(key);
        if (value == null) continue;
        await _primary.writeSecret(key, value);
      }
      // 注意：这里先只复制，不立刻清理 fallback。
      // 只有外层 primary 操作真正成功后，才会 finalize cleanup，
      // 避免“promotion 成功但当前 read/list 又失败”时把 fallback 清空。
    } catch (_) {
      // promotion 失败不影响后续操作，外层会根据 primary 操作结果更新 status
    } finally {
      _promotionLock!.complete();
      _promotionLock = null;
    }
  }

  Future<void> _finalizeFallbackPromotion() async {
    if (!_promotionNeeded) return;

    if (_promotionLock != null) {
      await _promotionLock!.future;
      return;
    }
    _promotionLock = Completer<void>();

    try {
      final fallbackKeys = await _fallback.listKeys();
      if (fallbackKeys.isEmpty) {
        _promotionNeeded = false;
        return;
      }
      for (final key in fallbackKeys) {
        await _fallback.deleteSecret(key);
      }
      _promotionNeeded = false;
    } catch (_) {
      // cleanup 失败时保留 fallback 数据，下次成功操作再尝试清理
    } finally {
      _promotionLock!.complete();
      _promotionLock = null;
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
    _promotionNeeded = true;
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
