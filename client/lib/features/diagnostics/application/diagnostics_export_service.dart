import 'dart:convert';

import '../../controller/application/client_controller_api.dart';
import '../../packaging/application/packaging_store.dart';
import '../../profiles/application/profile_portability_service.dart';
import '../../profiles/application/profile_store.dart';
import '../../settings/application/settings_store.dart';
import '../../../platform/secure_storage/secure_storage.dart';
import '../../../platform/services/diagnostics_file_exporter.dart';

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
  });

  final ProfileStore profileStore;
  final ProfilePortabilityService profilePortability;
  final SettingsStore settingsStore;
  final PackagingStore packagingStore;
  final ClientControllerApi controller;
  final SecureStorage secureStorage;
  final DiagnosticsFileExporter fileExporter;

  Future<String> buildPreviewBundle() async {
    final selected = profileStore.selectedProfile;
    final keys = await secureStorage.listKeys();
    final controllerHealth = await controller.checkHealth();
    final releaseManifest = packagingStore.buildReleaseManifest();
    final updateMetadata = packagingStore.buildUpdateMetadataSnapshot();

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
        'diagnosticsRetentionDays': settingsStore.settings.diagnosticsRetentionDays,
      },
      'secureStorage': {
        'backend': secureStorage.backendName,
        'storedKeyCount': keys.length,
        'keys': keys,
      },
      'packaging': {
        'workflow': {
          'channel': packagingStore.state.selectedChannel.name,
          'currentVersionLabel': packagingStore.state.currentVersionLabel,
          'updateChecksEnabled': packagingStore.state.updateChecksEnabled,
          'installerSkeletonReady': packagingStore.state.installerSkeletonReady,
          'exportStatus': packagingStore.state.exportStatus.name,
          'lastCheckSummary': packagingStore.state.lastCheckSummary,
          'lastExport': packagingStore.state.lastExport == null
              ? null
              : {
                  'startedAt': packagingStore.state.lastExport!.startedAt.toIso8601String(),
                  'finishedAt': packagingStore.state.lastExport!.finishedAt?.toIso8601String(),
                  'status': packagingStore.state.lastExport!.status.name,
                  'manifestTarget': packagingStore.state.lastExport!.manifestTarget,
                  'metadataTarget': packagingStore.state.lastExport!.metadataTarget,
                  'rollbackPlanTarget': packagingStore.state.lastExport!.rollbackPlanTarget,
                  'error': packagingStore.state.lastExport!.error,
                },
        },
        'releaseManifest': releaseManifest.toJson(),
        'updateMetadata': updateMetadata.toJson(),
        'exportHistory': packagingStore.exportHistory
            .map(
              (record) => <String, Object?>{
                'startedAt': record.startedAt.toIso8601String(),
                'finishedAt': record.finishedAt?.toIso8601String(),
                'status': record.status.name,
                'manifestTarget': record.manifestTarget,
                'metadataTarget': record.metadataTarget,
                'rollbackPlanTarget': record.rollbackPlanTarget,
                'error': record.error,
              },
            )
            .toList(),
      },
      'exportPreview': selected == null ? null : profilePortability.exportProfile(selected),
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<DiagnosticsExportResult> exportPreviewBundle() async {
    final contents = await buildPreviewBundle();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final target = await fileExporter.exportText(
      fileName: 'diagnostics-$timestamp.json',
      contents: contents,
    );
    return DiagnosticsExportResult(target: target, contents: contents);
  }
}
