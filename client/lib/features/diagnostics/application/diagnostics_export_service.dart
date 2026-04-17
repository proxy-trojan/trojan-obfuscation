import 'dart:convert';

import '../../../platform/secure_storage/secure_storage.dart';
import '../../../platform/services/app_runtime_error_store.dart';
import '../../../platform/services/diagnostics_file_exporter.dart';
import '../../controller/application/client_controller_api.dart';
import '../../controller/domain/controller_command_result.dart';
import '../../controller/domain/controller_runtime_session.dart';
import '../../controller/domain/runtime_posture.dart';
import '../../diagnostics/domain/routing_evidence_record.dart';
import '../../diagnostics/domain/routing_recovery_record.dart';
import '../../packaging/application/packaging_store.dart';
import '../../routing/testing/domain/routing_probe_models.dart';
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
    this.routingEvidenceRecords = const <RoutingEvidenceRecord>[],
    this.routingRecoveryRecords = const <RoutingRecoveryRecord>[],
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
  final List<RoutingEvidenceRecord> routingEvidenceRecords;
  final List<RoutingRecoveryRecord> routingRecoveryRecords;

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
    final diagnosticsCommand = await controller.collectDiagnostics(
      bundleKind: bundleKind,
    );
    final exportPreparationCommand = await controller.prepareExport(
      bundleKind: bundleKind,
    );
    final readinessReport = await readiness.buildReport();
    final controllerStatus = controller.status;
    final controllerTelemetry = controller.telemetry;
    final controllerRuntimeConfig = controller.runtimeConfig;
    final runtimeSession = controller.session;
    final resolvedRoutingEvidenceRecords = _resolvedRoutingEvidenceRecords();
    final resolvedRoutingRecoveryRecords = _resolvedRoutingRecoveryRecords();
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
              'routing': {
                'mode': selected.routing.mode.name,
                'defaultAction': selected.routing.defaultAction.name,
                'globalAction': selected.routing.globalAction.name,
                'ruleCount': selected.routing.rules.length,
                'policyGroupCount': selected.routing.policyGroups.length,
              },
            },
      'readiness': readinessReport.toJson(),
      'controller': {
        'phase': controllerStatus.phase.name,
        'message': controllerStatus.message,
        'activeProfileId': controllerStatus.activeProfileId,
        'updatedAt': controllerStatus.updatedAt.toIso8601String(),
        'safeModeActive': controllerStatus.safeModeActive,
        'quarantineKey': controllerStatus.quarantineKey,
        'rollbackReason': controllerStatus.rollbackReason,
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
                'rollbackReason': event.rollbackReason,
                'quarantineKey': event.quarantineKey,
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
      'routingEvidence':
          resolvedRoutingEvidenceRecords.map((record) => record.toJson()).toList(),
      'routingRecoveryEvidence':
          resolvedRoutingRecoveryRecords.map((record) => record.toJson()).toList(),
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

  Map<String, Object?> _normalizeRuntimeEvidence({
    required ControllerCommandResult command,
    required String commandName,
  }) {
    final rawDetails = command.details;
    final nestedDetails = rawDetails['details'];
    final nestedMap =
        nestedDetails is Map<String, Object?> ? nestedDetails : null;
    final bundleKind = rawDetails['bundleKind']?.toString() ??
        nestedMap?['bundleKind']?.toString();
    final evidenceClass = rawDetails['evidenceClass']?.toString() ??
        nestedMap?['evidenceClass']?.toString();

    final evidence = <String, Object?>{};
    void addEvidence(String key) {
      if (rawDetails.containsKey(key)) {
        evidence[key] = rawDetails[key];
      }
    }

    addEvidence('backendKind');
    addEvidence('backendVersion');
    addEvidence('binaryPathHint');
    addEvidence('transportEndpointHint');
    addEvidence('runtimeMode');
    addEvidence('runtimePhase');
    addEvidence('health');
    addEvidence('session');
    addEvidence('launchPlan');
    addEvidence('logTail');
    addEvidence('safeToExport');
    addEvidence('includesBinaryPathHint');
    addEvidence('includesLaunchPlan');
    addEvidence('includesSessionEvidence');
    addEvidence('includesLogTail');

    return <String, Object?>{
      'command': commandName,
      'commandId': command.commandId,
      'accepted': command.accepted,
      'completedAt': command.completedAt.toIso8601String(),
      'summary': command.summary,
      'error': command.error,
      'bundleKind': bundleKind,
      'evidenceClass': evidenceClass,
      'evidence': evidence,
      'rawDetails': rawDetails,
    };
  }

  List<RoutingEvidenceRecord> _resolvedRoutingEvidenceRecords() {
    if (routingEvidenceRecords.isNotEmpty) {
      return routingEvidenceRecords;
    }

    return controller.latestRoutingProbeEvidence
        .map(_mapProbeEvidenceToDiagnostics)
        .toList();
  }

  RoutingEvidenceRecord _mapProbeEvidenceToDiagnostics(
    RoutingProbeEvidenceRecord record,
  ) {
    return RoutingEvidenceRecord(
      scenarioId: record.scenarioId,
      platform: record.platform.name,
      phase: record.phase.name,
      decisionAction: record.decisionAction.name,
      observedResult: record.observedResult.name,
      errorType: record.errorType.name,
      errorDetail: record.errorDetail,
      fallbackApplied: record.fallbackApplied,
      runtimePosture: record.runtimePosture.name,
      runtimeTrueDataplane: record.isRuntimeTrueDataplane,
      timestamp: record.timestamp,
      matchedRuleId: record.matchedRuleId,
      policyGroupId: record.policyGroupId,
      explain: record.explain,
    );
  }

  List<RoutingRecoveryRecord> _resolvedRoutingRecoveryRecords() {
    if (routingRecoveryRecords.isNotEmpty) {
      return routingRecoveryRecords;
    }

    final status = controller.status;
    final rollbackReason = status.rollbackReason;
    if (!status.safeModeActive || rollbackReason == null || rollbackReason.isEmpty) {
      return const <RoutingRecoveryRecord>[];
    }

    return <RoutingRecoveryRecord>[
      RoutingRecoveryRecord(
        operationId: 'runtime-safe-mode',
        profileId: status.activeProfileId ?? 'unknown',
        rollbackReason: rollbackReason,
        safeModeActivated: true,
        quarantined: status.quarantineKey != null,
        quarantineKey: status.quarantineKey,
        timestamp: status.updatedAt,
      ),
    ];
  }

  @Deprecated('Use exportSupportBundle instead.')
  Future<DiagnosticsExportResult> exportPreviewBundle() {
    return exportSupportBundle();
  }
}
