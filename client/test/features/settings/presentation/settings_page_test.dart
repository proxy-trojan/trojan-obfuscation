import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/controller/application/fake_client_controller.dart';
import 'package:trojan_pro_client/features/diagnostics/application/diagnostics_export_service.dart';
import 'package:trojan_pro_client/features/packaging/application/packaging_export_service.dart';
import 'package:trojan_pro_client/features/packaging/application/packaging_store.dart';
import 'package:trojan_pro_client/features/profiles/application/profile_portability_service.dart';
import 'package:trojan_pro_client/features/profiles/application/profile_secrets_service.dart';
import 'package:trojan_pro_client/features/profiles/application/profile_serialization.dart';
import 'package:trojan_pro_client/features/profiles/application/profile_store.dart';
import 'package:trojan_pro_client/features/settings/application/settings_serialization.dart';
import 'package:trojan_pro_client/features/settings/application/settings_store.dart';
import 'package:trojan_pro_client/features/settings/presentation/settings_page.dart';
import 'package:trojan_pro_client/platform/services/memory_diagnostics_file_exporter.dart';
import 'package:trojan_pro_client/platform/services/memory_local_state_store.dart';
import 'package:trojan_pro_client/platform/services/noop_desktop_lifecycle_service.dart';
import 'package:trojan_pro_client/platform/services/service_registry.dart';
import 'package:trojan_pro_client/platform/secure_storage/memory_secure_storage.dart';

Future<void> _setDesktopSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1600, 1400));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });
}

ClientServiceRegistry _buildServices() {
  final localState = MemoryLocalStateStore();
  final secureStorage = MemorySecureStorage();
  final diagnosticsExporter = MemoryDiagnosticsFileExporter();
  final profileStore = ProfileStore.withSampleProfiles(
    localStateStore: localState,
    serialization: ProfileSerialization(),
    saveDebounceDuration: Duration.zero,
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
    desktopLifecycle: NoopDesktopLifecycleService(),
  );
}

void main() {
  testWidgets('shows desktop lifecycle semantics section',
      (WidgetTester tester) async {
    await _setDesktopSurface(tester);
    final services = _buildServices();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPage(services: services),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Desktop lifecycle policy'), findsOneWidget);
    expect(find.text('Window close behavior'), findsOneWidget);
    expect(find.text('Check for updates now'), findsOneWidget);
    expect(find.text('Update channel skeleton'), findsOneWidget);
    expect(find.textContaining('Close:'), findsOneWidget);
    expect(find.textContaining('Minimize:'), findsOneWidget);
    expect(find.textContaining('Quit:'), findsOneWidget);
    expect(find.textContaining('Lifecycle status:'), findsOneWidget);
    expect(find.textContaining('Tray integration:'), findsOneWidget);
    expect(find.textContaining('Close interception:'), findsOneWidget);
    expect(find.textContaining('Duplicate launch:'), findsOneWidget);
    expect(find.textContaining('Tray policy:'), findsOneWidget);
    expect(find.textContaining('Quick actions profile:'), findsOneWidget);
    expect(find.textContaining('Quick actions readiness:'), findsOneWidget);
    expect(find.textContaining('External activation:'), findsOneWidget);
  });

  testWidgets('shows external activation summary after focus handoff is recorded',
      (WidgetTester tester) async {
    await _setDesktopSurface(tester);
    final services = _buildServices();
    await services.desktopLifecycle.recordExternalActivation(
      source: 'secondary-launch-focus-ipc',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPage(services: services),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.textContaining('secondary-launch-focus-ipc'),
      findsOneWidget,
    );
  });
}
