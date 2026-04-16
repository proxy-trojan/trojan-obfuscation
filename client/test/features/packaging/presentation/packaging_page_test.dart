import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/controller/application/fake_client_controller.dart';
import 'package:trojan_pro_client/features/diagnostics/application/diagnostics_export_service.dart';
import 'package:trojan_pro_client/features/packaging/application/packaging_export_service.dart';
import 'package:trojan_pro_client/features/packaging/application/packaging_store.dart';
import 'package:trojan_pro_client/features/packaging/presentation/packaging_page.dart';
import 'package:trojan_pro_client/features/profiles/application/profile_portability_service.dart';
import 'package:trojan_pro_client/features/profiles/application/profile_secrets_service.dart';
import 'package:trojan_pro_client/features/profiles/application/profile_serialization.dart';
import 'package:trojan_pro_client/features/profiles/application/profile_store.dart';
import 'package:trojan_pro_client/features/readiness/application/readiness_service.dart';
import 'package:trojan_pro_client/features/settings/application/settings_serialization.dart';
import 'package:trojan_pro_client/features/settings/application/settings_store.dart';
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

Future<void> _setCompactSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(430, 1400));
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
  final readiness = ReadinessService(
    profileStore: profileStore,
    profileSecrets: profileSecrets,
    secureStorage: secureStorage,
    controller: controller,
  );
  final diagnostics = DiagnosticsExportService(
    profileStore: profileStore,
    profilePortability: profilePortability,
    settingsStore: settingsStore,
    packagingStore: packagingStore,
    controller: controller,
    secureStorage: secureStorage,
    fileExporter: diagnosticsExporter,
    readiness: readiness,
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
    readiness: readiness,
    diagnostics: diagnostics,
    desktopLifecycle: NoopDesktopLifecycleService(),
  );
}

void main() {
  testWidgets('packaging page stays usable on compact width',
      (WidgetTester tester) async {
    await _setCompactSurface(tester);
    final services = _buildServices();
    services.packagingStore.startExport();
    services.packagingStore.completeExport(
      manifestTarget: '/tmp/manifest.json',
      metadataTarget: '/tmp/update.json',
      rollbackPlanTarget: '/tmp/rollback.json',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PackagingPage(services: services),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Update Status'), findsOneWidget);
    expect(find.text('Export History'), findsOneWidget);
    expect(find.textContaining('manifest=/tmp/manifest.json'), findsOneWidget);
    expect(find.textContaining('Readiness: scaffolded'), findsNWidgets(2));
    expect(find.textContaining('Readiness: validated'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows update skeleton contract and stub action',
      (WidgetTester tester) async {
    await _setDesktopSurface(tester);
    final services = _buildServices();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PackagingPage(services: services),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Check for Updates (Stub)'), findsOneWidget);
    expect(find.textContaining('Metadata Contract'), findsOneWidget);
    expect(find.textContaining('Contract Version'), findsOneWidget);
    expect(find.text('1.5.0-beta.2'), findsOneWidget);
    expect(find.text('beta'), findsWidgets);
  });

  testWidgets(
      'packaging page reflects packaged smoke and release truth posture',
      (WidgetTester tester) async {
    await _setDesktopSurface(tester);
    final services = _buildServices();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PackagingPage(services: services),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('release truth + packaged smoke gates'),
        findsOneWidget);
    expect(
        find.textContaining(
            'Validated locally; packaged smoke gate is in place'),
        findsOneWidget);
    expect(find.textContaining('packaged smoke gate is wired in CI'),
        findsNWidgets(2));
    expect(find.textContaining('before CI/runtime validation exists'),
        findsNothing);
  });
}
