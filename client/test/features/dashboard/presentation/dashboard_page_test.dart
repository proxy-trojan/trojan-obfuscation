import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/controller/application/fake_client_controller.dart';
import 'package:trojan_pro_client/features/controller/domain/client_connection_status.dart';
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

Future<void> _setDesktopSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1600, 1400));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });
}

Future<void> _showDashboard(
  WidgetTester tester, {
  required ClientServiceRegistry services,
}) async {
  await _setDesktopSurface(tester);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DashboardPage(services: services),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpUntilPhase(
  WidgetTester tester,
  FakeClientController controller,
  ClientConnectionPhase phase,
) async {
  for (var i = 0; i < 20; i++) {
    if (controller.status.phase == phase) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
}

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

    await _showDashboard(tester, services: services);
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

    await _showDashboard(tester, services: services);

    expect(find.text('Connection Home'), findsOneWidget);
    expect(find.text('Open Troubleshooting'), findsWidgets);
    expect(find.text('Open Profiles'), findsWidgets);
  });

  testWidgets('connect now CTA triggers a connection attempt',
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

    await _showDashboard(tester, services: services);

    final connectFinder = find.widgetWithText(FilledButton, 'Connect now');
    expect(connectFinder, findsOneWidget);
    await tester.ensureVisible(connectFinder);
    await tester.pump();

    await tester.tap(connectFinder);
    await tester.pump();
    await _pumpUntilPhase(
      tester,
      services.controller as FakeClientController,
      ClientConnectionPhase.connected,
    );

    expect(services.controller.status.phase, ClientConnectionPhase.connected);
  });

  testWidgets('dashboard distinguishes selected and active profile',
      (WidgetTester tester) async {
    final services = _buildServices();
    final first = services.profileStore.selectedProfile!;
    final second = services.profileStore.profiles[1];
    await services.profileSecrets.saveTrojanPassword(
      profileId: first.id,
      password: 'secret-1',
    );
    await services.profileSecrets.saveTrojanPassword(
      profileId: second.id,
      password: 'secret-2',
    );
    services.profileStore
        .upsertProfile(first.copyWith(hasStoredPassword: true));
    services.profileStore
        .upsertProfile(second.copyWith(hasStoredPassword: true));
    services.profileStore.selectProfile(first.id);
    await tester.runAsync(() => services.controller.connect(first));
    services.profileStore.selectProfile(second.id);

    await _showDashboard(tester, services: services);

    expect(find.text('Selected Profile'), findsOneWidget);
    expect(find.text('Sample • United States'), findsWidgets);
    expect(find.text('Sample • Hong Kong'), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'Disconnect now'), findsOneWidget);
  });

  testWidgets('disconnect now CTA tears down an active connection',
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
    await tester.runAsync(() => services.controller.connect(profile));

    await _showDashboard(tester, services: services);

    final disconnectFinder =
        find.widgetWithText(FilledButton, 'Disconnect now');
    expect(disconnectFinder, findsOneWidget);
    await tester.ensureVisible(disconnectFinder);
    await tester.pump();

    await tester.tap(disconnectFinder);
    await tester.pump();
    await _pumpUntilPhase(
      tester,
      services.controller as FakeClientController,
      ClientConnectionPhase.disconnected,
    );

    expect(
      services.controller.status.phase,
      ClientConnectionPhase.disconnected,
    );
  });
}
