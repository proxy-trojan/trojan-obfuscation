import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'desktop_lifecycle_models.dart';

class DesktopInstanceGuard {
  static const String _focusMessage = 'focus';
  static const String _defaultLockName = 'trojan_pro_client.desktop.lock';
  static const String _lockNameEnvVar = 'TROJAN_CLIENT_SINGLE_INSTANCE_LOCK_NAME';

  static RandomAccessFile? _lockHandle;
  static ServerSocket? _focusServer;
  static String? _lockName;
  static String? _focusNonce;
  static Future<void> Function()? _focusRequestHandler;

  static Future<bool> tryAcquirePrimaryLock({
    String? lockName,
  }) async {
    if (!isDesktopPlatform()) {
      return true;
    }
    if (_lockHandle != null) {
      return true;
    }

    final effectiveLockName = _resolveEffectiveLockName(lockName);
    final lockPath = _lockFilePath(effectiveLockName);
    final lockFile = File(lockPath);
    final handle = await lockFile.open(mode: FileMode.write);

    try {
      await handle.lock(FileLock.exclusive);
      _lockHandle = handle;
      _lockName = effectiveLockName;
      await _startFocusServer(effectiveLockName);
      return true;
    } catch (_) {
      await handle.close();
      await _notifyPrimaryToFocus(effectiveLockName);
      return false;
    }
  }

  static String resolveLockName({Map<String, String>? environment}) {
    final env = environment ?? Platform.environment;
    final override = env[_lockNameEnvVar]?.trim();
    if (override != null && override.isNotEmpty) {
      return override;
    }
    return _defaultLockName;
  }

  static void setFocusRequestHandler(Future<void> Function() handler) {
    _focusRequestHandler = handler;
  }

  static Future<void> release() async {
    final handle = _lockHandle;
    _lockHandle = null;

    final server = _focusServer;
    _focusServer = null;

    final lockName = _lockName;
    _lockName = null;
    _focusNonce = null;

    if (server != null) {
      try {
        await server.close();
      } catch (_) {
        // ignore
      }
    }

    if (lockName != null) {
      try {
        await File(_focusEndpointPath(lockName)).delete();
      } catch (_) {
        // ignore
      }
    }

    if (handle == null) return;

    try {
      await handle.unlock();
    } catch (_) {
      // ignore
    }
    try {
      await handle.close();
    } catch (_) {
      // ignore
    }
  }

  static Future<void> _startFocusServer(String lockName) async {
    final server = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
      shared: true,
    );
    _focusServer = server;

    // 生成格式校验 token，用于过滤随机噪声数据。
    // 注意：该 token 会明文写入临时文件供二次实例读取，因此不具备
    // 防恶意本地进程的安全认证能力，仅防止非预期的垃圾数据触发聚焦。
    final nonce = DateTime.now().microsecondsSinceEpoch.toRadixString(36) +
        pid.toRadixString(36);
    _focusNonce = nonce;

    final endpointFile = File(_focusEndpointPath(lockName));
    await endpointFile.writeAsString('${server.port}:$nonce', flush: true);

    unawaited(
      server.forEach((socket) async {
        String payload = '';
        try {
          // 限制接收 chunk 数和超时，防止恶意本地进程消耗内存
          payload = await utf8.decoder
              .bind(socket.take(4))
              .join()
              .timeout(const Duration(seconds: 2), onTimeout: () => '');
          if (payload.length > 256) {
            payload = '';
          }
        } catch (_) {
          // 忽略格式异常的数据
        } finally {
          try {
            await socket.close();
          } catch (_) {
            // ignore
          }
        }

        // 验证格式校验 token：格式为 "focus:<token>"
        final parts = payload.trim().split(':');
        if (parts.length != 2 ||
            parts[0] != _focusMessage ||
            parts[1] != _focusNonce) {
          return;
        }

        final handler = _focusRequestHandler;
        if (handler != null) {
          try {
            await handler();
          } catch (_) {
            // ignore callback failures
          }
        }
      }),
    );
  }

  static Future<void> _notifyPrimaryToFocus(String lockName) async {
    final endpointFile = File(_focusEndpointPath(lockName));
    if (!await endpointFile.exists()) {
      return;
    }

    final rawContent = await endpointFile.readAsString();
    final parts = rawContent.trim().split(':');
    if (parts.length != 2) return;

    final port = int.tryParse(parts[0]);
    final nonce = parts[1];
    if (port == null || nonce.isEmpty) {
      return;
    }

    Socket? socket;
    try {
      socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
        timeout: const Duration(milliseconds: 300),
      );
      socket.write('$_focusMessage:$nonce');
      await socket.flush();
    } catch (_) {
      // ignore notification failures
    } finally {
      try {
        await socket?.close();
      } catch (_) {
        // ignore
      }
    }
  }

  static String _resolveEffectiveLockName(String? lockName) {
    final candidate = lockName?.trim();
    if (candidate != null && candidate.isNotEmpty) {
      return candidate;
    }
    return resolveLockName();
  }

  static String _lockFilePath(String lockName) {
    return '${Directory.systemTemp.path}${Platform.pathSeparator}$lockName';
  }

  static String _focusEndpointPath(String lockName) {
    return '${Directory.systemTemp.path}${Platform.pathSeparator}$lockName.focus';
  }

  @visibleForTesting
  static Future<void> debugResetForTests() async {
    await release();
    _focusRequestHandler = null;
    _focusNonce = null;
  }

  @visibleForTesting
  static String debugEndpointPathForLockName(String lockName) {
    return _focusEndpointPath(lockName);
  }

  @visibleForTesting
  static Future<void> debugSignalPrimaryFocus(String lockName) async {
    await _notifyPrimaryToFocus(lockName);
  }
}
