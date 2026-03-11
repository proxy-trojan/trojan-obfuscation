import 'app/app.dart';
import 'features/controller/application/fake_client_controller.dart';
import 'features/diagnostics/application/diagnostics_export_service.dart';
import 'features/profiles/application/profile_portability_service.dart';
import 'features/profiles/application/profile_serialization.dart';
import 'features/profiles/application/profile_store.dart';
import 'features/settings/application/settings_serialization.dart';
import 'features/settings/application/settings_store.dart';
import 'platform/secure_storage/memory_secure_storage.dart';
import 'platform/services/memory_local_state_store.dart';
import 'platform/services/service_registry.dart';

class ClientBootstrap {
  static ClientServiceRegistry createServices() {
    final secureStorage = MemorySecureStorage();
    final localStateStore = MemoryLocalStateStore();
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
    final controller = FakeClientController();
    profileStore.load();
    settingsStore.load();

    final diagnostics = DiagnosticsExportService(
      profileStore: profileStore,
      profilePortability: profilePortability,
      settingsStore: settingsStore,
      controller: controller,
      secureStorage: secureStorage,
    );

    return ClientServiceRegistry(
      secureStorage: secureStorage,
      localStateStore: localStateStore,
      profileStore: profileStore,
      profilePortability: profilePortability,
      settingsStore: settingsStore,
      controller: controller,
      diagnostics: diagnostics,
    );
  }
}
