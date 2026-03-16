import 'dart:convert';

import '../../../platform/secure_storage/secure_storage.dart';
import '../../../platform/services/app_runtime_error_store.dart';
import '../../../platform/services/diagnostics_file_exporter.dart';
import '../../controller/application/client_controller_api.dart';
import '../../packaging/application/packaging_store.dart';
import '../../profiles/application/profile_portability_service.dart';
import '../../profiles/application/profile_store.dart';
import '../../settings/application/settings_store.dart';

class DiagnosticsExportResult {
  const DiagnosticsExportResult({
    required this.target,
    required this.contents,
  });

  final String target;
  final String contents;
}

class DiagnosticsExportService {
  DiagnosticsExportService({
    required this.profileStore,
    required this.profilePortability,
    required this.settingsStore,
    required this.packagingStore,
    required this.controller,
    required this.secureStorage,
    required this.fileExporter,
    AppRuntimeErrorStore? appRuntimeErrors,
  }) : appRuntimeErrors = appRuntimeErrors ?? AppRuntimeErrorStore();

  final ProfileStore profileStore;
  final ProfilePortabilityService profilePortability;
  final SettingsStore settingsStore;
  final PackagingStore packagingStore;
  final ClientControllerApi controller;
  final SecureStorage secureStorage;
  final DiagnosticsFileExporter fileExporter;
  final AppRuntimeErrorStore appRuntimeErrors;

  Future<String> buildPreviewBundle() async {
    final selected = profileStore.selectedProfile;
    final keys = await secureStorage.listKeys();
    final controllerHealth = await controller.checkHealth();
    final releaseManifest = packagingStore.buildReleaseManifest();
    final updateMetadata = packagingStore.buildUpdateMetadataSnapshot();
    final storageStatus = secureStorage.status;
    final appUnhandledError = appRuntimeErrors.lastUnhandledError;

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
              'hasStoredPassword': selected.hasStoredPassword,
            },
      'controller': {
        'phase': controller.status.phase.name,
        'message': controller.status.message,
        'activeProfileId': controller.status.activeProfileId,
        'updatedAt': controller.status.updatedAt.toIso8601String(),
        'telemetry': {
          'backendKind': controller.telemetry.backendKind,
          'backendVersion': controller.telemetry.backendVersion,
          'capabilities': controller.telemetry.capabilities,
          'lastUpdatedAt': controller.telemetry.lastUpdatedAt.toIso8601String(),
        },
        'runtimeConfig': controller.runtimeConfig.toJson(),
        'runtimeHealth': {
          'level': controllerHealth.level.name,
          'summary': controllerHealth.summary,
          'updatedAt': controllerHealth.updatedAt.toIso8601String(),
        },
        'runtimeSession': controller.session.toJson(),
        'recentEvents': controller.recentEvents
            .map(
              (event) => <String, Object?>{
                'id': event.id,
                'timestamp': event.timestamp.toIso8601String(),
                'title': event.title,
                'message': event.message,
                'phase': event.phase.name,
                'level': event.level.name,
                'kind': event.kind.name,
                'profileId': event.profileId,
                'operationId': event.operationId,
                'step': event.step,
              },
            )
            .toList(),
      },
      'settings': {
        'themeMode': settingsStore.settings.themeMode.name,
        'updateChannel': settingsStore.settings.updateChannel.name,
        'launchOnLogin': settingsStore.settings.launchOnLogin,
        'collectDiagnostics': settingsStore.settings.collectDiagnostics,
        'diagnosticsRetentionDays':
            settingsStore.settings.diagnosticsRetentionDays,
      },
      'appRuntime': {
        'lastUnhandledError': appUnhandledError == null
            ? null
            : {
                'source': appUnhandledError.source,
                'message': appUnhandledError.message,
                'stackPreview': appUnhandledError.stackPreview,
                'recordedAt': appUnhandledError.recordedAt.toIso8601String(),
              },
      },
      'secureStorage': {
        'backend': secureStorage.backendName,
        'activeBackend': storageStatus.activeBackendName,
        'mode': storageStatus.storageModeLabel,
        'summary': storageStatus.userFacingSummary,
        'isSecure': storageStatus.isSecure,
        'isPersistent': storageStatus.isPersistent,
        'fallbackEnabled': storageStatus.fallbackEnabled,
        'keys': keys,
      },
      'release': {
        'manifest': releaseManifest.toJson(),
        'updateMetadata': updateMetadata.toJson(),
      },
      'profilesExport':
          jsonDecode(profilePortability.exportProfiles(profileStore.profiles)),
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<DiagnosticsExportResult> exportSupportBundle() async {
    final contents = await buildPreviewBundle();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final target = await fileExporter.exportText(
      fileName: 'trojan-pro-support-$timestamp.json',
      contents: contents,
    );
    return DiagnosticsExportResult(target: target, contents: contents);
  }

  @Deprecated('Use exportSupportBundle instead.')
  Future<DiagnosticsExportResult> exportPreviewBundle() {
    return exportSupportBundle();
  }
}
