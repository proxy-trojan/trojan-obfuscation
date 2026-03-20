import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/controller/application/client_controller_api.dart';
import 'package:trojan_pro_client/features/controller/application/fake_client_controller.dart';
import 'package:trojan_pro_client/features/controller/domain/client_connection_status.dart';
import 'package:trojan_pro_client/features/controller/domain/controller_runtime_health.dart';
import 'package:trojan_pro_client/features/diagnostics/application/diagnostics_export_service.dart';
import 'package:trojan_pro_client/features/packaging/application/packaging_export_service.dart';
import 'package:trojan_pro_client/features/packaging/application/packaging_store.dart';
import 'package:trojan_pro_client/features/profiles/application/profile_portability_service.dart';
import 'package:trojan_pro_client/features/profiles/application/profile_secrets_service.dart';
import 'package:trojan_pro_client/features/profiles/application/profile_serialization.dart';
import 'package:trojan_pro_client/features/profiles/application/profile_store.dart';
import 'package:trojan_pro_client/features/profiles/presentation/profiles_page.dart';
import 'package:trojan_pro_client/features/readiness/application/readiness_service.dart';
import 'package:trojan_pro_client/features/settings/application/settings_serialization.dart';
import 'package:trojan_pro_client/features/settings/application/settings_store.dart';
import 'package:trojan_pro_client/platform/services/memory_diagnostics_file_exporter.dart';
import 'package:trojan_pro_client/platform/services/memory_local_state_store.dart';
import 'package:trojan_pro_client/platform/services/service_registry.dart';
import 'package:trojan_pro_client/platform/secure_storage/memory_secure_storage.dart';

Future<void> _setDesktopSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1800, 1600));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });
}

class _UnavailableRuntimeController extends FakeClientController {
  @override
  Future<ControllerRuntimeHealth> checkHealth() async {
    return ControllerRuntimeHealth(
      level: ControllerRuntimeHealthLevel.unavailable,
      summary: 'runtime binary missing for this test',
      updatedAt: DateTime.parse('2026-03-20T00:00:00.000Z'),
    );
  }
}

ClientServiceRegistry _buildServices(
    {ClientControllerApi? controllerOverride}) {
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
  final controller = controllerOverride ?? FakeClientController();

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
  );
}

void main() {
  testWidgets('disables connect until password is stored',
      (WidgetTester tester) async {
    await _setDesktopSurface(tester);
    final services = _buildServices();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProfilesPage(services: services)),
      ),
    );
    await tester.pump();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Set Password First'),
    );
    expect(button.onPressed, isNull);
    expect(
      find.text(
          'Controller status: Save the Trojan password before trying this profile.'),
      findsOneWidget,
    );
  });

  testWidgets('disables connect on another profile while one is connected',
      (WidgetTester tester) async {
    await _setDesktopSurface(tester);
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

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProfilesPage(services: services)),
      ),
    );
    await tester.pump();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Connected Elsewhere'),
    );
    expect(button.onPressed, isNull);
    expect(
      find.text(
        'Controller status: Another profile is already connected. Disconnect it before switching here.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('blocks connect action when readiness is blocked',
      (WidgetTester tester) async {
    await _setDesktopSurface(tester);
    final services = _buildServices();
    final selected = services.profileStore.selectedProfile!;

    await services.profileSecrets.saveTrojanPassword(
      profileId: selected.id,
      password: 'secret',
    );
    services.profileStore.upsertProfile(
      selected.copyWith(
        hasStoredPassword: true,
        serverHost: '',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProfilesPage(services: services)),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Readiness: Blocked'), findsOneWidget);
    expect(
      find.textContaining('Check server host / server port / local SOCKS port'),
      findsWidgets,
    );

    final blockedButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Connect Blocked'),
    );
    expect(blockedButton.onPressed, isNull);

    expect(
        services.controller.status.phase, ClientConnectionPhase.disconnected);
    expect(find.textContaining('Recommended next step: Open Profiles'),
        findsOneWidget);
  });

  testWidgets(
      'readiness notice refreshes when selected profile changes in place',
      (WidgetTester tester) async {
    await _setDesktopSurface(tester);
    final services = _buildServices();
    final selected = services.profileStore.selectedProfile!;

    await services.profileSecrets.saveTrojanPassword(
      profileId: selected.id,
      password: 'secret',
    );
    services.profileStore.upsertProfile(
      selected.copyWith(
        hasStoredPassword: true,
        serverHost: '',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProfilesPage(services: services)),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Readiness: Blocked'), findsOneWidget);

    final refreshed = services.profileStore.selectedProfile!.copyWith(
      serverHost: 'hk-edge.example.com',
      hasStoredPassword: true,
      updatedAt: DateTime.now().add(const Duration(seconds: 1)),
    );
    services.profileStore.upsertProfile(refreshed);

    await tester.pump();
    await tester.pump();

    expect(find.text('Readiness: Ready with warnings'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Connect'), findsOneWidget);
  });

  testWidgets('readiness recommendation button can route to troubleshooting',
      (WidgetTester tester) async {
    await _setDesktopSurface(tester);
    final services = _buildServices(
      controllerOverride: _UnavailableRuntimeController(),
    );
    final selected = services.profileStore.selectedProfile!;

    await services.profileSecrets.saveTrojanPassword(
      profileId: selected.id,
      password: 'secret',
    );
    services.profileStore.upsertProfile(
      selected.copyWith(hasStoredPassword: true),
    );

    var openedAdvanced = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfilesPage(
            services: services,
            onOpenAdvanced: (_) => openedAdvanced = true,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Recommended next step: Open Troubleshooting'),
        findsOneWidget);

    await tester
        .tap(find.widgetWithText(OutlinedButton, 'Open Troubleshooting'));
    await tester.pump();

    expect(openedAdvanced, isTrue);
  });
}
