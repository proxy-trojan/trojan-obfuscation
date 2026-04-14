import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/platform/services/desktop_instance_guard.dart';
import 'package:trojan_pro_client/platform/services/desktop_lifecycle_models.dart';

void main() {
  test('resolveLockName uses environment override when provided', () {
    const override = 'trojan_pro_client.packaged_smoke.test.desktop.lock';

    final resolved = DesktopInstanceGuard.resolveLockName(
      environment: {
        'TROJAN_CLIENT_SINGLE_INSTANCE_LOCK_NAME': override,
      },
    );

    expect(resolved, override);
  });

  test('resolveLockName falls back to default lock name', () {
    final resolved = DesktopInstanceGuard.resolveLockName(environment: const {});

    expect(resolved, 'trojan_pro_client.desktop.lock');
  });

  test('lock acquisition still succeeds when focus IPC startup fails', () async {
    if (!isDesktopPlatform()) {
      return;
    }

    final lockName =
        'trojan_pro_client.test.${DateTime.now().microsecondsSinceEpoch}.ipc-fail.lock';
    await DesktopInstanceGuard.debugResetForTests();

    DesktopInstanceGuard.debugSetFocusServerStarterForTests((_) {
      throw const SocketException('focus-startup-failed');
    });

    final primary = await DesktopInstanceGuard.tryAcquirePrimaryLock(
      lockName: lockName,
    );

    expect(primary, isTrue);

    await DesktopInstanceGuard.debugResetForTests();
    final lockPath = '${Directory.systemTemp.path}${Platform.pathSeparator}$lockName';
    expect(await File(lockPath).exists(), isTrue);
    await File(lockPath).delete();
  });

  test('secondary focus signal reaches primary instance handler', () async {
    if (!isDesktopPlatform()) {
      return;
    }

    final lockName =
        'trojan_pro_client.test.${DateTime.now().microsecondsSinceEpoch}.lock';
    await DesktopInstanceGuard.debugResetForTests();

    final primary = await DesktopInstanceGuard.tryAcquirePrimaryLock(
      lockName: lockName,
    );
    expect(primary, isTrue);

    final endpointPath =
        DesktopInstanceGuard.debugEndpointPathForLockName(lockName);
    expect(await File(endpointPath).exists(), isTrue);

    final focusRequested = Completer<void>();
    DesktopInstanceGuard.setFocusRequestHandler(() async {
      if (!focusRequested.isCompleted) {
        focusRequested.complete();
      }
    });

    await DesktopInstanceGuard.debugSignalPrimaryFocus(lockName);

    await expectLater(
      focusRequested.future.timeout(const Duration(seconds: 1)),
      completes,
    );

    await DesktopInstanceGuard.debugResetForTests();
    expect(await File(endpointPath).exists(), isFalse);
  });
}
