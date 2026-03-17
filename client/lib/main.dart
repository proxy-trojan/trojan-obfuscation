import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'app/app.dart';
import 'bootstrap.dart';
import 'platform/services/desktop_instance_guard.dart';
import 'platform/services/service_registry.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final primaryInstance = await DesktopInstanceGuard.tryAcquirePrimaryLock();
  if (!primaryInstance) {
    debugPrint(
      'Trojan-Pro Client: another desktop instance is already running; secondary launch exits.',
    );
    exit(0);
  }

  late final ClientServiceRegistry services;
  try {
    services = await ClientBootstrap.createServices(
      singleInstancePrimary: primaryInstance,
    );
  } catch (error, stackTrace) {
    debugPrint('Trojan-Pro Client: bootstrap failed: $error\n$stackTrace');
    // 显示最小化的错误 UI，防止白屏崩溃
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'App startup failed.\n\n'
                'Please try clearing app data or reinstalling.\n'
                'Error reference: ${error.runtimeType}',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    unawaited(
      services.appRuntimeErrors.record(
        source: 'flutter_framework',
        error: details.exception,
        stackTrace: details.stack,
      ),
    );
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stackTrace) {
    unawaited(
      services.appRuntimeErrors.record(
        source: 'platform_dispatcher',
        error: error,
        stackTrace: stackTrace,
      ),
    );
    return true;
  };

  DesktopInstanceGuard.setFocusRequestHandler(() async {
    await services.desktopLifecycle.recordExternalActivation(
      source: 'secondary-launch-focus-ipc',
    );
    await services.desktopLifecycle.showMainWindow();
  });

  // 进程退出前刷盘：确保 debounce 中未完成的写入不丢失
  AppLifecycleListener(onExitRequested: () async {
    await services.dispose();
    return AppExitResponse.exit;
  });

  runZonedGuarded(
    () {
      runApp(TrojanClientApp(services: services));
    },
    (Object error, StackTrace stackTrace) {
      unawaited(
        services.appRuntimeErrors.record(
          source: 'zone_guard',
          error: error,
          stackTrace: stackTrace,
        ),
      );
      debugPrint('Uncaught zoned error: $error');
    },
  );
}
