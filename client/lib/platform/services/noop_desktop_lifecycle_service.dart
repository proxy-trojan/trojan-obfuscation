import 'desktop_lifecycle_models.dart';
import 'desktop_lifecycle_service.dart';

class NoopDesktopLifecycleService extends DesktopLifecycleService {
  NoopDesktopLifecycleService({DesktopLifecyclePolicy? policy})
      : _policy = policy ?? DesktopLifecyclePolicy.fallback,
        _status = DesktopLifecycleStatus.unsupported();

  DesktopLifecyclePolicy _policy;
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
  Future<void> applyPolicy(DesktopLifecyclePolicy policy) async {
    _policy = policy;
    _status = _status.copyWith(
      summary: policy.closeSemanticsSummary(trayReady: false),
    );
    notifyListeners();
  }

  @override
  Future<void> updateQuickActions(DesktopQuickActionsState state) async {}

  @override
  Future<void> minimizeMainWindow() async {}

  @override
  Future<void> requestQuit() async {}

  @override
  Future<void> showMainWindow() async {}

  @override
  Future<void> disposeService() async {}
}
