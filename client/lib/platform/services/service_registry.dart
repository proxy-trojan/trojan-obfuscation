import 'dart:async';

import '../../features/controller/application/client_controller_api.dart';
import '../../features/diagnostics/application/diagnostics_export_service.dart';
import '../../features/packaging/application/packaging_export_service.dart';
import '../../features/packaging/application/packaging_store.dart';
import '../../features/profiles/application/profile_portability_service.dart';
import '../../features/profiles/application/profile_secrets_service.dart';
import '../../features/profiles/application/profile_store.dart';
import '../../features/settings/application/settings_store.dart';
import '../secure_storage/secure_storage.dart';
import 'app_runtime_error_store.dart';
import 'desktop_lifecycle_service.dart';
import 'diagnostics_file_exporter.dart';
import 'local_state_store.dart';
import 'noop_desktop_lifecycle_service.dart';

class ClientServiceRegistry {
  ClientServiceRegistry({
    required this.secureStorage,
    required this.localStateStore,
    required this.diagnosticsFileExporter,
    required this.profileStore,
    required this.profilePortability,
    required this.profileSecrets,
    required this.packagingStore,
    required this.packagingExport,
    required this.settingsStore,
    required this.controller,
    required this.diagnostics,
    DesktopLifecycleService? desktopLifecycle,
    AppRuntimeErrorStore? appRuntimeErrors,
  })  : desktopLifecycle = desktopLifecycle ?? NoopDesktopLifecycleService(),
        appRuntimeErrors = appRuntimeErrors ?? AppRuntimeErrorStore();

  final SecureStorage secureStorage;
  final LocalStateStore localStateStore;
  final DiagnosticsFileExporter diagnosticsFileExporter;
  final ProfileStore profileStore;
  final ProfilePortabilityService profilePortability;
  final ProfileSecretsService profileSecrets;
  final PackagingStore packagingStore;
  final PackagingExportService packagingExport;
  final SettingsStore settingsStore;
  final ClientControllerApi controller;
  final DiagnosticsExportService diagnostics;
  final DesktopLifecycleService desktopLifecycle;
  final AppRuntimeErrorStore appRuntimeErrors;

  /// bootstrap 阶段注册的 listener，dispose 时统一移除。
  final List<_ListenerBinding> _listenerBindings = <_ListenerBinding>[];

  void registerListener(Listenable listenable, VoidCallback callback) {
    listenable.addListener(callback);
    _listenerBindings.add(_ListenerBinding(listenable, callback));
  }

  SecureStorageStatus get secureStorageStatus => secureStorage.status;

  /// 释放所有 ChangeNotifier 和 listener，应在 app 退出时调用。
  Future<void> dispose() async {
    // 先移除所有 bootstrap 阶段注册的 listener
    for (final binding in _listenerBindings) {
      binding.listenable.removeListener(binding.callback);
    }
    _listenerBindings.clear();

    // 释放 desktop lifecycle（包含 tray、window listener 等平台资源）
    await desktopLifecycle.disposeService();

    // 释放各 ChangeNotifier
    controller.dispose();
    profileStore.dispose();
    settingsStore.dispose();
    packagingStore.dispose();
    appRuntimeErrors.dispose();
  }
}

class _ListenerBinding {
  const _ListenerBinding(this.listenable, this.callback);

  final Listenable listenable;
  final VoidCallback callback;
}
