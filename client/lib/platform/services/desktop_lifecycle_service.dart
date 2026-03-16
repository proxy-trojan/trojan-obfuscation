import 'package:flutter/foundation.dart';

import 'desktop_lifecycle_models.dart';

typedef DesktopQuitHandler = Future<void> Function();

abstract class DesktopLifecycleService extends ChangeNotifier {
  DesktopLifecyclePolicy get policy;

  DesktopLifecycleStatus get status;

  Future<void> initialize();

  Future<void> showMainWindow();

  Future<void> minimizeMainWindow();

  Future<void> requestQuit();

  Future<void> disposeService();
}
