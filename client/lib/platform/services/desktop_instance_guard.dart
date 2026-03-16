import 'dart:io';

import 'desktop_lifecycle_models.dart';

class DesktopInstanceGuard {
  static RandomAccessFile? _lockHandle;

  static Future<bool> tryAcquirePrimaryLock({
    String lockName = 'trojan_pro_client.desktop.lock',
  }) async {
    if (!isDesktopPlatform()) {
      return true;
    }
    if (_lockHandle != null) {
      return true;
    }

    final lockPath =
        '${Directory.systemTemp.path}${Platform.pathSeparator}$lockName';
    final lockFile = File(lockPath);
    final handle = await lockFile.open(mode: FileMode.write);

    try {
      await handle.lock(FileLock.exclusive);
      _lockHandle = handle;
      return true;
    } catch (_) {
      await handle.close();
      return false;
    }
  }

  static Future<void> release() async {
    final handle = _lockHandle;
    _lockHandle = null;
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
}
