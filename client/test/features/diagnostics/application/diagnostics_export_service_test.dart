import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/controller/application/fake_client_controller.dart';
import 'package:trojan_pro_client/features/controller/domain/controller_runtime_config.dart';
import 'package:trojan_pro_client/features/controller/domain/controller_telemetry_snapshot.dart';
import 'package:trojan_pro_client/features/controller/domain/failure_family.dart';
import 'package:trojan_pro_client/features/controller/domain/last_runtime_failure_summary.dart';
import 'package:trojan_pro_client/features/diagnostics/application/diagnostics_export_service.dart';
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

class _RuntimeTrueController extends FakeClientController {
  @override
  ControllerRuntimeConfig get runtimeConfig => const ControllerRuntimeConfig(
        mode: 'real-runtime-boundary',
        endpointHint: 'unix:/tmp/trojan-runtime.sock',
        enableVerboseTelemetry: false,
      );

  @override
  ControllerTelemetrySnapshot get telemetry => ControllerTelemetrySnapshot(
        backendKind: 'real-shell-controller',
        backendVersion: 'test-runtime-true',
        capabilities: const <String>['spawn', 'logs'],
        lastUpdatedAt: DateTime.parse('2026-03-24T12:00:00.000Z'),
      );
}

class _ControllerWithFailureSummary extends FakeClientController {
  @override
  LastRuntimeFailureSummary? get lastRuntimeFailure =>
      LastRuntimeFailureSummary(
        profileId: 'sample-hk-1',
        phase: 'runtime',
        family: FailureFamily.connect,
        headline: 'The runtime session exited unexpectedly',
        detail: 'Exit code 7',
        recordedAt: DateTime.parse('2026-04-14T07:00:00.000Z'),
      );
}

void main() {
  test('buildPreviewBundle includes app runtime summary and profiles bundle',
      () async {
    final localState = MemoryLocalStateStore();
    final diagnosticsExporter = MemoryDiagnosticsFileExporter();
    final secureStorage = MemorySecureStorage();
    final profileStore = ProfileStore.withSampleProfiles(
      localStateStore: localState,
      serialization: ProfileSerialization(),
    );
    final settingsStore = SettingsStore(
      localStateStore: localState,
      serialization: SettingsSerialization(),
    );
    final packagingStore = PackagingStore();
    final controller = FakeClientController();

    final appRuntimeErrors = AppRuntimeErrorStore(localStateStore: localState);
    await appRuntimeErrors.record(
      source: 'zone_guard',
      error: StateError('background task exploded'),
      stackTrace: StackTrace.current,
    );
    await ProfileSecretsService(secureStorage: secureStorage)
        .saveTrojanPassword(
      profileId: 'sample-hk-1',
      password: 'super-secret-password',
    );

    final readiness = ReadinessService(
      profileStore: profileStore,
      profileSecrets: ProfileSecretsService(secureStorage: secureStorage),
      secureStorage: secureStorage,
      controller: controller,
    );

    final diagnostics = DiagnosticsExportService(
      profileStore: profileStore,
      profilePortability: ProfilePortabilityService(),
      settingsStore: settingsStore,
      packagingStore: packagingStore,
      controller: controller,
      secureStorage: secureStorage,
      fileExporter: diagnosticsExporter,
      readiness: readiness,
      appRuntimeErrors: appRuntimeErrors,
    );

    final preview = await diagnostics.buildPreviewBundle();
    final payload = jsonDecode(preview) as Map<String, dynamic>;

    expect(payload['bundleKind'], 'support-bundle');

    final selectedProfile = payload['selectedProfile'] as Map<String, dynamic>;
    final selectedRouting = selectedProfile['routing'] as Map<String, dynamic>;
    expect(selectedRouting['mode'], 'rule');
    expect(selectedRouting['defaultAction'], 'proxy');
    expect(selectedRouting['globalAction'], 'proxy');
    expect(selectedRouting['ruleCount'], 0);
    expect(selectedRouting['policyGroupCount'], 0);

    final controllerPayload = payload['controller'] as Map<String, dynamic>;
    final runtimePosture =
        controllerPayload['runtimePosture'] as Map<String, dynamic>;
    final operatorGuidance =
        runtimePosture['operatorGuidance'] as Map<String, dynamic>;
    final runtimeSession =
        controllerPayload['runtimeSession'] as Map<String, dynamic>;
    final runtimeEvidence =
        controllerPayload['runtimeEvidence'] as Map<String, dynamic>;
    final lastRuntimeFailure =
        controllerPayload['lastRuntimeFailure'] as Map<String, dynamic>?;

    expect(operatorGuidance['heading'],
        'How to use support bundles on this posture');
    expect((operatorGuidance['checklist'] as List<dynamic>).isNotEmpty, isTrue);
    expect(runtimeSession['truth'], 'Residual snapshot');
    expect(runtimeSession['needsAttention'], isTrue);
    expect(runtimeSession['recoveryGuidance'], contains('retry from Profiles'));
    expect(
      (runtimeEvidence['collectDiagnostics']
          as Map<String, dynamic>)['accepted'],
      isTrue,
    );
    expect(
      (runtimeEvidence['collectDiagnostics']
          as Map<String, dynamic>)['bundleKind'],
      'support-bundle',
    );
    expect(
      (runtimeEvidence['collectDiagnostics']
          as Map<String, dynamic>)['command'],
      'collectDiagnostics',
    );
    expect(
      (runtimeEvidence['collectDiagnostics']
          as Map<String, dynamic>)['evidence'] is Map<String, dynamic>,
      isTrue,
    );
    expect(
      (runtimeEvidence['prepareExport'] as Map<String, dynamic>)['accepted'],
      isTrue,
    );
    expect(lastRuntimeFailure, isNull);
    expect(controllerPayload['safeModeActive'], isFalse);
    expect(controllerPayload['quarantineKey'], isNull);
    expect(controllerPayload['rollbackReason'], isNull);

    final appRuntime = payload['appRuntime'] as Map<String, dynamic>;
    final lastUnhandledError =
        appRuntime['lastUnhandledError'] as Map<String, dynamic>;
    expect(lastUnhandledError['source'], 'zone_guard');
    expect(lastUnhandledError['message'], contains('background task exploded'));

    final profilesExport = payload['profilesExport'] as Map<String, dynamic>;
    expect(profilesExport['kind'], 'trojan-pro-client-profile-bundle');
    final profiles = profilesExport['profiles'] as List<dynamic>;
    expect(profiles, hasLength(profileStore.profiles.length));

    expect(preview, isNot(contains('super-secret-password')));
  });

  test('buildPreviewBundle includes last runtime failure family when present',
      () async {
    final localState = MemoryLocalStateStore();
    final diagnosticsExporter = MemoryDiagnosticsFileExporter();
    final secureStorage = MemorySecureStorage();

    final profileStore = ProfileStore.withSampleProfiles(
      localStateStore: localState,
      serialization: ProfileSerialization(),
      saveDebounceDuration: Duration.zero,
    );
    final controller = _ControllerWithFailureSummary();
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
      fileExporter: diagnosticsExporter,
      readiness: readiness,
      appRuntimeErrors: AppRuntimeErrorStore(localStateStore: localState),
    );

    final preview = await diagnostics.buildPreviewBundle();
    final payload = jsonDecode(preview) as Map<String, dynamic>;
    final controllerPayload = payload['controller'] as Map<String, dynamic>;
    final lastRuntimeFailure =
        controllerPayload['lastRuntimeFailure'] as Map<String, dynamic>?;

    expect(lastRuntimeFailure, isNotNull);
    expect(lastRuntimeFailure!['phase'], 'runtime');
    expect(lastRuntimeFailure['family'], 'connect');
    expect(lastRuntimeFailure['headline'],
        'The runtime session exited unexpectedly');
  });

  test('runtime-proof artifact export requires evidence-grade posture',
      () async {
    final localState = MemoryLocalStateStore();
    final diagnosticsExporter = MemoryDiagnosticsFileExporter();
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
      fileExporter: diagnosticsExporter,
      readiness: readiness,
      appRuntimeErrors: AppRuntimeErrorStore(localStateStore: localState),
    );

    await expectLater(
      diagnostics.buildRuntimeProofArtifact(),
      throwsA(isA<StateError>()),
    );
  });

  test(
      'runtime-proof artifact export uses promoted file name on evidence-grade path',
      () async {
    final localState = MemoryLocalStateStore();
    final diagnosticsExporter = MemoryDiagnosticsFileExporter();
    final secureStorage = MemorySecureStorage();

    final profileStore = ProfileStore.withSampleProfiles(
      localStateStore: localState,
      serialization: ProfileSerialization(),
      saveDebounceDuration: Duration.zero,
    );
    final controller = _RuntimeTrueController();
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
      fileExporter: diagnosticsExporter,
      readiness: readiness,
      appRuntimeErrors: AppRuntimeErrorStore(localStateStore: localState),
    );

    final result = await diagnostics.exportRuntimeProofArtifact();
    final payload = jsonDecode(result.contents) as Map<String, dynamic>;
    final controllerPayload = payload['controller'] as Map<String, dynamic>;
    final runtimePosture =
        controllerPayload['runtimePosture'] as Map<String, dynamic>;
    final operatorGuidance =
        runtimePosture['operatorGuidance'] as Map<String, dynamic>;

    expect(payload['bundleKind'], 'runtime-proof-artifact');
    expect(operatorGuidance['heading'], 'How to use runtime-proof artifacts');
    expect(result.target,
        startsWith('memory://diagnostics/trojan-pro-runtime-proof-'));
    expect(
      diagnosticsExporter.exports.keys.single,
      startsWith('trojan-pro-runtime-proof-'),
    );
  });

  test('exportPreviewBundle delegates to support bundle export path', () async {
    final localState = MemoryLocalStateStore();
    final diagnosticsExporter = MemoryDiagnosticsFileExporter();
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
      fileExporter: diagnosticsExporter,
      readiness: readiness,
      appRuntimeErrors: AppRuntimeErrorStore(localStateStore: localState),
    );

    final result = await diagnostics.exportPreviewBundle();

    expect(
        result.target, startsWith('memory://diagnostics/trojan-pro-support-'));
    expect(diagnosticsExporter.exports.keys.single,
        startsWith('trojan-pro-support-'));
    expect(result.contents, contains('"controller"'));
  });
}
