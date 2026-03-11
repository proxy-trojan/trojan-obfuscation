import '../../features/controller/application/client_controller_api.dart';
import '../../features/diagnostics/application/diagnostics_export_service.dart';
import '../../features/profiles/application/profile_portability_service.dart';
import '../../features/profiles/application/profile_store.dart';
import '../../features/settings/application/settings_store.dart';
import '../secure_storage/secure_storage.dart';
import 'local_state_store.dart';

class ClientServiceRegistry {
  ClientServiceRegistry({
    required this.secureStorage,
    required this.localStateStore,
    required this.profileStore,
    required this.profilePortability,
    required this.settingsStore,
    required this.controller,
    required this.diagnostics,
  });

  final SecureStorage secureStorage;
  final LocalStateStore localStateStore;
  final ProfileStore profileStore;
  final ProfilePortabilityService profilePortability;
  final SettingsStore settingsStore;
  final ClientControllerApi controller;
  final DiagnosticsExportService diagnostics;
}
