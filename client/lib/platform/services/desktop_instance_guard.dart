import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'desktop_lifecycle_models.dart';

class DesktopInstanceGuard {
  static const String _focusMessage = 'focus';

  static RandomAccessFile? _lockHandle;
  static ServerSocket? _focusServer;
  static String? _lockName;
  static Future<void> Function()? _focusRequestHandler;

  static Future<bool> tryAcquirePrimaryLock({
    String lockName = 'trojan_pro_client.desktop.lock',
  }) async {
    if (!isDesktopPlatform()) {
      return true;
    }
    if (_lockHandle != null) {
      return true;
    }

    final lockPath = _lockFilePath(lockName);
    final lockFile = File(lockPath);
    final handle = await lockFile.open(mode: FileMode.write);

    try {
      await handle.lock(FileLock.exclusive);
      _lockHandle = handle;
      _lockName = lockName;
      await _startFocusServer(lockName);
      return true;
    } catch (_) {
      await handle.close();
      await _notifyPrimaryToFocus(lockName);
      return false;
    }
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

    final endpointFile = File(_focusEndpointPath(lockName));
    await endpointFile.writeAsString('${server.port}', flush: true);

    unawaited(
      server.forEach((socket) async {
        String payload = '';
        try {
          payload = await utf8.decoder.bind(socket).join();
        } catch (_) {
          // ignore malformed payload
        } finally {
          try {
            await socket.close();
          } catch (_) {
            // ignore
          }
        }

        if (payload.trim() != _focusMessage) {
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

    final rawPort = await endpointFile.readAsString();
    final port = int.tryParse(rawPort.trim());
    if (port == null) {
      return;
    }

    Socket? socket;
    try {
      socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
        timeout: const Duration(milliseconds: 300),
      );
      socket.write(_focusMessage);
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
