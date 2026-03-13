import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/controller/application/fake_client_controller.dart';
import 'package:trojan_pro_client/features/dashboard/presentation/dashboard_page.dart';
import 'package:trojan_pro_client/features/diagnostics/application/diagnostics_export_service.dart';
import 'package:trojan_pro_client/features/packaging/application/packaging_export_service.dart';
import 'package:trojan_pro_client/features/packaging/application/packaging_store.dart';
import 'package:trojan_pro_client/features/profiles/application/profile_portability_service.dart';
import 'package:trojan_pro_client/features/profiles/application/profile_secrets_service.dart';
import 'package:trojan_pro_client/features/profiles/application/profile_serialization.dart';
import 'package:trojan_pro_client/features/profiles/application/profile_store.dart';
import 'package:trojan_pro_client/features/settings/application/settings_serialization.dart';
import 'package:trojan_pro_client/features/settings/application/settings_store.dart';
import 'package:trojan_pro_client/platform/services/memory_diagnostics_file_exporter.dart';
import 'package:trojan_pro_client/platform/services/memory_local_state_store.dart';
import 'package:trojan_pro_client/platform/services/service_registry.dart';
import 'package:trojan_pro_client/platform/secure_storage/memory_secure_storage.dart';

ClientServiceRegistry _buildServices() {
  final localState = MemoryLocalStateStore();
  final secureStorage = MemorySecureStorage();
  final diagnosticsExporter = MemoryDiagnosticsFileExporter();
  final profileStore = ProfileStore.withSampleProfiles(
    localStateStore: localState,
    serialization: ProfileSerialization(),
  );
  final profilePortability = ProfilePortabilityService();
  final profileSecrets = ProfileSecretsService(secureStorage: secureStorage);
  final packagingStore = PackagingStore();
  final settingsStore = SettingsStore(
    localStateStore: localState,
    serialization: SettingsSerialization(),
  );
  final controller = FakeClientController();

  final packagingExport = PackagingExportService(
    packagingStore: packagingStore,
    fileExporter: diagnosticsExporter,
  );
  final diagnostics = DiagnosticsExportService(
    profileStore: profileStore,
    profilePortability: profilePortability,
    settingsStore: settingsStore,
    packagingStore: packagingStore,
    controller: controller,
    secureStorage: secureStorage,
    fileExporter: diagnosticsExporter,
  );

  return ClientServiceRegistry(
    secureStorage: secureStorage,
    localStateStore: localState,
    diagnosticsFileExporter: diagnosticsExporter,
    profileStore: profileStore,
    profilePortability: profilePortability,
    profileSecrets: profileSecrets,
    packagingStore: packagingStore,
    packagingExport: packagingExport,
    settingsStore: settingsStore,
    controller: controller,
    diagnostics: diagnostics,
  );
}

void main() {
  testWidgets('shows startup guidance when no password is stored',
      (WidgetTester tester) async {
    final services = _buildServices();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardPage(services: services),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Save the password before testing'), findsWidgets);
    expect(find.text('Open Profiles'), findsWidgets);
  });

  testWidgets('shows connection home CTAs when profile is ready',
      (WidgetTester tester) async {
    final services = _buildServices();
    final profile = services.profileStore.selectedProfile!;
    await services.profileSecrets.saveTrojanPassword(
      profileId: profile.id,
      password: 'secret',
    );
    services.profileStore.upsertProfile(
      profile.copyWith(hasStoredPassword: true),
    );

    await tester.runAsync(
      () => services.controller.connect(services.profileStore.selectedProfile!),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardPage(services: services),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Connection Home'), findsOneWidget);
    expect(find.text('Open Troubleshooting'), findsWidgets);
    expect(find.text('Open Profiles'), findsWidgets);
  });
}
