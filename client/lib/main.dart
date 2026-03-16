import 'dart:io';

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

  DesktopInstanceGuard.setFocusRequestHandler(() async {
    await services.desktopLifecycle.showMainWindow();
  });

  runApp(TrojanClientApp(services: services));
}
