import 'dart:convert';

import '../../controller/application/client_controller_api.dart';
import '../../profiles/application/profile_portability_service.dart';
import '../../profiles/application/profile_store.dart';
import '../../settings/application/settings_store.dart';
import '../../../platform/secure_storage/secure_storage.dart';

class DiagnosticsExportService {
  DiagnosticsExportService({
    required this.profileStore,
    required this.profilePortability,
    required this.settingsStore,
    required this.controller,
    required this.secureStorage,
  });

  final ProfileStore profileStore;
  final ProfilePortabilityService profilePortability;
  final SettingsStore settingsStore;
  final ClientControllerApi controller;
  final SecureStorage secureStorage;

  Future<String> buildPreviewBundle() async {
    final selected = profileStore.selectedProfile;
    final keys = await secureStorage.listKeys();

    final payload = <String, Object?>{
      'generatedAt': DateTime.now().toIso8601String(),
      'profileCount': profileStore.profiles.length,
      'selectedProfile': selected == null
          ? null
          : {
              'id': selected.id,
              'name': selected.name,
              'serverHost': selected.serverHost,
              'serverPort': selected.serverPort,
              'sni': selected.sni,
            },
      'controller': {
        'phase': controller.status.phase.name,
        'message': controller.status.message,
        'activeProfileId': controller.status.activeProfileId,
        'updatedAt': controller.status.updatedAt.toIso8601String(),
      },
      'settings': {
        'themeMode': settingsStore.settings.themeMode.name,
        'updateChannel': settingsStore.settings.updateChannel.name,
        'launchOnLogin': settingsStore.settings.launchOnLogin,
        'collectDiagnostics': settingsStore.settings.collectDiagnostics,
        'diagnosticsRetentionDays': settingsStore.settings.diagnosticsRetentionDays,
      },
      'secureStorage': {
        'backend': secureStorage.backendName,
        'storedKeyCount': keys.length,
        'keys': keys,
      },
      'exportPreview': selected == null ? null : profilePortability.exportProfile(selected),
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }
}
