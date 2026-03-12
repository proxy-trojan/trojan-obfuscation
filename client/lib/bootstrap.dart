import 'features/controller/application/adapter_backed_client_controller.dart';
import 'features/controller/application/fake_shell_controller_adapter.dart';
import 'features/controller/application/real_shell_controller_adapter.dart';
import 'features/controller/application/shell_controller_adapter.dart';
import 'features/diagnostics/application/diagnostics_export_service.dart';
import 'features/packaging/application/packaging_export_service.dart';
import 'features/packaging/application/packaging_store.dart';
import 'features/profiles/application/profile_portability_service.dart';
import 'features/profiles/application/profile_secrets_service.dart';
import 'features/profiles/application/profile_serialization.dart';
import 'features/profiles/application/profile_store.dart';
import 'features/settings/application/settings_serialization.dart';
import 'features/settings/application/settings_store.dart';
import 'platform/secure_storage/fallback_secure_storage.dart';
import 'platform/secure_storage/flutter_secure_storage_adapter.dart';
import 'platform/secure_storage/memory_secure_storage.dart';
import 'platform/secure_storage/secure_storage.dart';
import 'platform/services/client_filesystem_layout.dart';
import 'platform/services/file_backed_local_state_store.dart';
import 'platform/services/file_diagnostics_file_exporter.dart';
import 'platform/services/memory_diagnostics_file_exporter.dart';
import 'platform/services/memory_local_state_store.dart';
import 'platform/services/service_registry.dart';

import 'dart:io';

class ClientBootstrap {
  static Future<ClientServiceRegistry> createServices() async {
    final secureStorage = _createSecureStorage();
    final filesystemLayout = ClientFilesystemLayout.maybeForCurrentPlatform();
    final localStateStore = filesystemLayout == null
        ? MemoryLocalStateStore()
        : FileBackedLocalStateStore(directoryPath: filesystemLayout.stateDirectoryPath);
    final diagnosticsFileExporter = filesystemLayout == null
        ? MemoryDiagnosticsFileExporter()
        : FileDiagnosticsFileExporter(directoryPath: filesystemLayout.diagnosticsDirectoryPath);
    final profileSerialization = ProfileSerialization();
    final settingsSerialization = SettingsSerialization();
    final profileStore = ProfileStore.withSampleProfiles(
      localStateStore: localStateStore,
      serialization: profileSerialization,
    );
    final settingsStore = SettingsStore(
      localStateStore: localStateStore,
      serialization: settingsSerialization,
    );
    final profilePortability = ProfilePortabilityService();
    final profileSecrets = ProfileSecretsService(secureStorage: secureStorage);
    final packagingStore = PackagingStore();
    final packagingExport = PackagingExportService(
      packagingStore: packagingStore,
      fileExporter: diagnosticsFileExporter,
    );
    final controller = AdapterBackedClientController(
      adapter: _createShellControllerAdapter(),
      profileSecrets: profileSecrets,
      filesystemLayout: filesystemLayout,
    );

    await profileStore.load();
    await settingsStore.load();

    final secretSnapshots = await profileSecrets.snapshotForProfiles(profileStore.profiles);
    await profileStore.syncStoredPasswordFlags(<String, bool>{
      for (final snapshot in secretSnapshots)
        snapshot.profileId: snapshot.hasTrojanPassword,
    });
    packagingStore.syncUpdatePreferences(
      channel: settingsStore.settings.updateChannel,
      autoCheckForUpdates: settingsStore.settings.autoCheckForUpdates,
    );
    packagingStore.markInstallerSkeletonReady();

    final diagnostics = DiagnosticsExportService(
      profileStore: profileStore,
      profilePortability: profilePortability,
      settingsStore: settingsStore,
      packagingStore: packagingStore,
      controller: controller,
      secureStorage: secureStorage,
      fileExporter: diagnosticsFileExporter,
    );

    return ClientServiceRegistry(
      secureStorage: secureStorage,
      localStateStore: localStateStore,
      diagnosticsFileExporter: diagnosticsFileExporter,
      profileStore: profileStore,
      profilePortability: profilePortability,
      profileSecrets: profileSecrets,
      packagingStore: packagingStore,
      packagingExport: packagingExport,
      settingsStore: settingsStore,
      controller: controller,
      diagnostics: diagnostics,
    );
  }

  static SecureStorage _createSecureStorage() {
    return FallbackSecureStorage(
      primary: FlutterSecureStorageAdapter(),
      fallback: MemorySecureStorage(),
    );
  }

  static ShellControllerAdapter _createShellControllerAdapter() {
    final env = Platform.environment;
    final enableRealAdapter =
        (env['TROJAN_CLIENT_ENABLE_REAL_ADAPTER'] ?? '').trim().toLowerCase() == '1' ||
        (env['TROJAN_CLIENT_ENABLE_REAL_ADAPTER'] ?? '').trim().toLowerCase() == 'true';
    final binaryOverride = (env['TROJAN_CLIENT_BINARY'] ?? '').trim();

    if (enableRealAdapter) {
      return RealShellControllerAdapter(
        binaryPathHint: binaryOverride.isEmpty ? 'ENV_UNSET' : binaryOverride,
      );
    }
    return FakeShellControllerAdapter();
  }
}
