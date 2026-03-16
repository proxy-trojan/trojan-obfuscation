import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/platform/services/desktop_instance_guard.dart';
import 'package:trojan_pro_client/platform/services/desktop_lifecycle_models.dart';

void main() {
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
