import '../../features/controller/application/client_controller_api.dart';
import '../../features/diagnostics/application/diagnostics_export_service.dart';
import '../../features/packaging/application/packaging_export_service.dart';
import '../../features/packaging/application/packaging_store.dart';
import '../../features/profiles/application/profile_portability_service.dart';
import '../../features/profiles/application/profile_secrets_service.dart';
import '../../features/profiles/application/profile_store.dart';
import '../../features/settings/application/settings_store.dart';
import '../secure_storage/secure_storage.dart';
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
  }) : desktopLifecycle = desktopLifecycle ?? NoopDesktopLifecycleService();

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

  SecureStorageStatus get secureStorageStatus => secureStorage.status;
}
