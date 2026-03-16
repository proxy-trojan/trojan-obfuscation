import 'desktop_lifecycle_models.dart';
import 'desktop_lifecycle_service.dart';

class NoopDesktopLifecycleService extends DesktopLifecycleService {
  NoopDesktopLifecycleService({DesktopLifecyclePolicy? policy})
      : _policy = policy ?? DesktopLifecyclePolicy.fallback,
        _status = DesktopLifecycleStatus.unsupported();

  final DesktopLifecyclePolicy _policy;
  DesktopLifecycleStatus _status;

  @override
  DesktopLifecyclePolicy get policy => _policy;

  @override
  DesktopLifecycleStatus get status => _status;

  @override
  Future<void> initialize() async {
    _status = DesktopLifecycleStatus.unsupported();
    notifyListeners();
  }

  @override
  Future<void> minimizeMainWindow() async {}

  @override
  Future<void> requestQuit() async {}

  @override
  Future<void> showMainWindow() async {}

  @override
  Future<void> disposeService() async {}
}
