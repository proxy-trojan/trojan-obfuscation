import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'bootstrap.dart';
import 'platform/services/desktop_instance_guard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final primaryInstance = await DesktopInstanceGuard.tryAcquirePrimaryLock();
  if (!primaryInstance) {
    debugPrint(
      'Trojan-Pro Client: another desktop instance is already running; secondary launch exits.',
    );
    exit(0);
  }

  final services = await ClientBootstrap.createServices(
    singleInstancePrimary: primaryInstance,
  );

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
