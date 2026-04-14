import 'dart:convert';

import '../../../platform/secure_storage/secure_storage.dart';
import '../../../platform/services/app_runtime_error_store.dart';
import '../../../platform/services/diagnostics_file_exporter.dart';
import '../../controller/application/client_controller_api.dart';
import '../../controller/domain/controller_runtime_session.dart';
import '../../controller/domain/runtime_posture.dart';
import '../../packaging/application/packaging_store.dart';
import '../../profiles/application/profile_portability_service.dart';
import '../../profiles/application/profile_store.dart';
import '../../readiness/application/readiness_service.dart';
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
    required this.readiness,
    AppRuntimeErrorStore? appRuntimeErrors,
    this.adapterSelectionReason,
    this.expectedRealRuntimePath,
  }) : appRuntimeErrors = appRuntimeErrors ?? AppRuntimeErrorStore();

  final ProfileStore profileStore;
  final ProfilePortabilityService profilePortability;
  final SettingsStore settingsStore;
  final PackagingStore packagingStore;
  final ClientControllerApi controller;
  final SecureStorage secureStorage;
  final DiagnosticsFileExporter fileExporter;
  final ReadinessService readiness;
  final AppRuntimeErrorStore appRuntimeErrors;
  final String? adapterSelectionReason;
  final bool? expectedRealRuntimePath;

  Future<String> buildPreviewBundle() {
    return _buildBundle(bundleKind: 'support-bundle');
  }

  Future<String> buildRuntimeProofArtifact() async {
    final contents = await _buildBundle(bundleKind: 'runtime-proof-artifact');
    final payload = jsonDecode(contents) as Map<String, dynamic>;
    final runtimePosture = (payload['controller']
        as Map<String, dynamic>)['runtimePosture'] as Map<String, dynamic>;
    if (runtimePosture['evidenceGrade'] != 'Evidence-grade') {
      throw StateError(
        'Runtime-proof artifact export requires an Evidence-grade posture.',
      );
    }
    return contents;
  }

  Future<String> _buildBundle({required String bundleKind}) async {
    final selected = profileStore.selectedProfile;
    final keys = await secureStorage.listKeys();
    final controllerHealth = await controller.checkHealth();
    final readinessReport = await readiness.buildReport();
    final controllerStatus = controller.status;
    final controllerTelemetry = controller.telemetry;
    final controllerRuntimeConfig = controller.runtimeConfig;
    final runtimeSession = controller.session;
    final runtimePosture = describeRuntimePosture(
      runtimeMode: controllerRuntimeConfig.mode,
      backendKind: controllerTelemetry.backendKind,
    );
    final releaseManifest = packagingStore.buildReleaseManifest();
    final updateMetadata = packagingStore.buildUpdateMetadataSnapshot();
    final storageStatus = secureStorage.status;
    final appUnhandledError = appRuntimeErrors.lastUnhandledError;

    final payload = <String, Object?>{
      'bundleKind': bundleKind,
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
      'readiness': readinessReport.toJson(),
      'controller': {
        'phase': controllerStatus.phase.name,
        'message': controllerStatus.message,
        'activeProfileId': controllerStatus.activeProfileId,
        'updatedAt': controllerStatus.updatedAt.toIso8601String(),
        'telemetry': {
          'backendKind': controllerTelemetry.backendKind,
          'backendVersion': controllerTelemetry.backendVersion,
          'capabilities': controllerTelemetry.capabilities,
          'lastUpdatedAt': controllerTelemetry.lastUpdatedAt.toIso8601String(),
        },
        'runtimeConfig': controllerRuntimeConfig.toJson(),
        'runtimeHealth': {
          'level': controllerHealth.level.name,
          'summary': controllerHealth.summary,
          'updatedAt': controllerHealth.updatedAt.toIso8601String(),
        },
        'runtimeSession': {
          ...runtimeSession.toJson(),
          'truth': runtimeSession.truth.label,
          'needsAttention': runtimeSession.needsAttention,
          'truthNote': runtimeSession.truthNote,
          'recoveryGuidance': runtimeSession.recoveryGuidance,
        },
        'selection': {
          'expectedRealRuntimePath': expectedRealRuntimePath,
          'reason': adapterSelectionReason,
        },
        'runtimeEvidence': {
          'collectDiagnostics': _normalizeRuntimeEvidence(
            command: diagnosticsCommand,
            commandName: 'collectDiagnostics',
          ),
          'prepareExport': _normalizeRuntimeEvidence(
            command: exportPreparationCommand,
            commandName: 'prepareExport',
          ),
        },
        'lastRuntimeFailure': controller.lastRuntimeFailure?.toJson(),
        'runtimePosture': {
          'kind': runtimePosture.kind.name,
          'label': runtimePosture.postureLabel,
          'evidenceGrade': runtimePosture.evidenceGradeLabel,
          'executionPath': runtimePosture.executionPathLabel,
          'truthNote': runtimePosture.truthNote,
          'evidenceNote': runtimePosture.evidenceGradeNote,
          'artifactCapability': runtimePosture.artifactCapabilityLabel,
          'artifactCapabilityNote': runtimePosture.artifactCapabilityNote,
          'operatorGuidance': {
            'heading': runtimePosture.operatorGuidanceHeading,
            'checklist': runtimePosture.operatorChecklist,
          },
        },
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

  Future<DiagnosticsExportResult> exportRuntimeProofArtifact() async {
    final contents = await buildRuntimeProofArtifact();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final target = await fileExporter.exportText(
      fileName: 'trojan-pro-runtime-proof-$timestamp.json',
      contents: contents,
    );
    return DiagnosticsExportResult(target: target, contents: contents);
  }

  @Deprecated('Use exportSupportBundle instead.')
  Future<DiagnosticsExportResult> exportPreviewBundle() {
    return exportSupportBundle();
  }
}
