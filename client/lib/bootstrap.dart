import 'app/app.dart';
import 'features/controller/application/fake_client_controller.dart';
import 'features/diagnostics/application/diagnostics_export_service.dart';
import 'features/profiles/application/profile_portability_service.dart';
import 'features/profiles/application/profile_store.dart';
import 'features/settings/application/settings_store.dart';
import 'platform/secure_storage/memory_secure_storage.dart';
import 'platform/services/service_registry.dart';

class ClientBootstrap {
  static ClientServiceRegistry createServices() {
    final secureStorage = MemorySecureStorage();
    final profileStore = ProfileStore.withSampleProfiles();
    final settingsStore = SettingsStore();
    final profilePortability = ProfilePortabilityService();
    final controller = FakeClientController();
    final diagnostics = DiagnosticsExportService(
      profileStore: profileStore,
      profilePortability: profilePortability,
      settingsStore: settingsStore,
      controller: controller,
      secureStorage: secureStorage,
    );

    return ClientServiceRegistry(
      secureStorage: secureStorage,
      profileStore: profileStore,
      profilePortability: profilePortability,
      settingsStore: settingsStore,
      controller: controller,
      diagnostics: diagnostics,
    );
  }
}
