import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/controller/application/fake_client_controller.dart';
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
    await ProfileSecretsService(secureStorage: secureStorage).saveTrojanPassword(
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

    expect(result.target, startsWith('memory://diagnostics/trojan-pro-support-'));
    expect(diagnosticsExporter.exports.keys.single,
        startsWith('trojan-pro-support-'));
    expect(result.contents, contains('"controller"'));
  });
}
