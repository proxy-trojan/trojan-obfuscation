import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/controller/application/fake_client_controller.dart';
import 'package:trojan_pro_client/features/diagnostics/application/diagnostics_export_service.dart';
import 'package:trojan_pro_client/features/diagnostics/domain/routing_evidence_record.dart';
import 'package:trojan_pro_client/features/packaging/application/packaging_store.dart';
import 'package:trojan_pro_client/features/profiles/application/profile_portability_service.dart';
import 'package:trojan_pro_client/features/profiles/application/profile_secrets_service.dart';
import 'package:trojan_pro_client/features/profiles/application/profile_serialization.dart';
import 'package:trojan_pro_client/features/profiles/application/profile_store.dart';
import 'package:trojan_pro_client/features/readiness/application/readiness_service.dart';
import 'package:trojan_pro_client/features/settings/application/settings_serialization.dart';
import 'package:trojan_pro_client/features/settings/application/settings_store.dart';
import 'package:trojan_pro_client/platform/secure_storage/memory_secure_storage.dart';
import 'package:trojan_pro_client/platform/services/app_runtime_error_store.dart';
import 'package:trojan_pro_client/platform/services/memory_diagnostics_file_exporter.dart';
import 'package:trojan_pro_client/platform/services/memory_local_state_store.dart';

Future<String> exportDiagnosticsFixtureWithRoutingEvidence() async {
  final localState = MemoryLocalStateStore();
  final secureStorage = MemorySecureStorage();
  final profileStore = ProfileStore.withSampleProfiles(
    localStateStore: localState,
    serialization: ProfileSerialization(),
    saveDebounceDuration: Duration.zero,
  );
  final controller = FakeClientController();
  final readiness = ReadinessService(
    profileStore: profileStore,
    profileSecrets: ProfileSecretsService(secureStorage: secureStorage),
    secureStorage: secureStorage,
    controller: controller,
  );

  final diagnostics = DiagnosticsExportService(
    profileStore: profileStore,
    profilePortability: ProfilePortabilityService(),
    settingsStore: SettingsStore(
      localStateStore: localState,
      serialization: SettingsSerialization(),
    ),
    packagingStore: PackagingStore(),
    controller: controller,
    secureStorage: secureStorage,
    fileExporter: MemoryDiagnosticsFileExporter(),
    readiness: readiness,
    appRuntimeErrors: AppRuntimeErrorStore(localStateStore: localState),
    routingEvidenceRecords: <RoutingEvidenceRecord>[
      RoutingEvidenceRecord(
        scenarioId: 'rule-direct',
        platform: 'linux',
        phase: 'observe',
        decisionAction: 'direct',
        observedResult: 'direct',
        errorType: 'none',
        errorDetail: '',
        fallbackApplied: false,
        runtimePosture: 'runtimeTrue',
        runtimeTrueDataplane: true,
        timestamp: DateTime.parse('2026-04-16T06:30:00.000Z'),
        matchedRuleId: 'rule-1',
        policyGroupId: null,
        explain: 'matched direct rule',
        operationId: 'connect-17',
        rollbackReason: null,
        safeModeActive: false,
        quarantineKey: null,
      ),
    ],
  );

  return diagnostics.buildPreviewBundle();
}

void main() {
  test('diagnostics export includes routing evidence section', () async {
    final jsonText = await exportDiagnosticsFixtureWithRoutingEvidence();
    final payload = jsonDecode(jsonText) as Map<String, dynamic>;

    expect(payload['routingEvidence'], isNotNull);
    final evidence = payload['routingEvidence'] as List<dynamic>;
    expect(evidence, hasLength(1));
    final first = evidence.first as Map<String, dynamic>;
    expect(first['scenarioId'], 'rule-direct');
    expect(first['operationId'], 'connect-17');
    expect(first['safeModeActive'], isFalse);
  });
}
