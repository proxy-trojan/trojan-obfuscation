import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/controller/application/client_controller_api.dart';
import 'package:trojan_pro_client/features/controller/application/fake_client_controller.dart';
import 'package:trojan_pro_client/features/controller/domain/client_connection_status.dart';
import 'package:trojan_pro_client/features/controller/domain/controller_runtime_health.dart';
import 'package:trojan_pro_client/features/controller/domain/controller_runtime_session.dart';
import 'package:trojan_pro_client/features/diagnostics/application/diagnostics_export_service.dart';
import 'package:trojan_pro_client/features/packaging/application/packaging_export_service.dart';
import 'package:trojan_pro_client/features/packaging/application/packaging_store.dart';
import 'package:trojan_pro_client/features/profiles/application/profile_portability_service.dart';
import 'package:trojan_pro_client/features/profiles/application/profile_secrets_service.dart';
import 'package:trojan_pro_client/features/profiles/application/profile_serialization.dart';
import 'package:trojan_pro_client/features/profiles/application/profile_store.dart';
import 'package:trojan_pro_client/features/profiles/presentation/profiles_page.dart';
import 'package:trojan_pro_client/features/readiness/application/readiness_service.dart';
import 'package:trojan_pro_client/features/readiness/domain/readiness_report.dart';
import 'package:trojan_pro_client/features/settings/application/settings_serialization.dart';
import 'package:trojan_pro_client/features/settings/application/settings_store.dart';
import 'package:trojan_pro_client/platform/services/local_state_store.dart';
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

Future<void> _setCompactSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(430, 1600));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });
}

class _DelayedReadLocalStateStore implements LocalStateStore {
  static const Duration _readDelay = Duration(milliseconds: 200);

  final MemoryLocalStateStore _delegate = MemoryLocalStateStore();

  @override
  String get backendName => _delegate.backendName;

  @override
  Future<void> delete(String key) => _delegate.delete(key);

  @override
  Future<String?> read(String key) async {
    await Future<void>.delayed(_readDelay);
    return _delegate.read(key);
  }

  @override
  Future<void> write(String key, String value) => _delegate.write(key, value);
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

class _SlowHealthController extends FakeClientController {
  @override
  Future<ControllerRuntimeHealth> checkHealth() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return super.checkHealth();
  }
}

class _StaleConnectedController extends FakeClientController {
  ClientConnectionStatus statusOverride = ClientConnectionStatus(
    phase: ClientConnectionPhase.connected,
    message: 'Runtime session is ready.',
    updatedAt: DateTime.parse('2026-03-20T00:00:00.000Z'),
    activeProfileId: 'sample-hk-1',
  );

  ControllerRuntimeSession sessionOverride = ControllerRuntimeSession(
    isRunning: true,
    updatedAt: DateTime.now().subtract(const Duration(minutes: 3)),
    phase: ControllerRuntimePhase.sessionReady,
    expectedLocalSocksPort: 10808,
  );

  @override
  ClientConnectionStatus get status => statusOverride;

  @override
  ControllerRuntimeSession get session => sessionOverride;
}

class _SafeModeController extends FakeClientController {
  @override
  ClientConnectionStatus get status => ClientConnectionStatus(
        phase: ClientConnectionPhase.error,
        message: 'Routing apply failed and has been rolled back in Safe Mode.',
        updatedAt: DateTime.parse('2026-04-16T10:00:00.000Z'),
        activeProfileId: 'sample-hk-1',
        errorCode: 'ROUTING_APPLY_ROLLED_BACK_QUARANTINED',
        safeModeActive: true,
        quarantineKey: 'sample-hk-1',
        rollbackReason: 'mini smoke failed on routing rule smoke/direct',
      );
}

ClientServiceRegistry _buildServices({
  ClientControllerApi? controllerOverride,
  LocalStateStore? localStateOverride,
}) {
  final localState = localStateOverride ?? MemoryLocalStateStore();
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
    localStateStore: localState,
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

  testWidgets('profiles page stays usable on compact width',
      (WidgetTester tester) async {
    await _setCompactSurface(tester);
    final services = _buildServices();
    final selected = services.profileStore.selectedProfile!;

    await services.profileSecrets.saveTrojanPassword(
      profileId: selected.id,
      password: 'secret',
    );
    services.profileStore.upsertProfile(
      selected.copyWith(hasStoredPassword: true),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProfilesPage(services: services)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Profiles'), findsOneWidget);
    expect(find.text(selected.name), findsWidgets);
    expect(find.text('Server'), findsOneWidget);
    expect(find.text('Runtime Posture'), findsOneWidget);
    expect(find.text('Evidence Grade'), findsOneWidget);
    expect(find.text('Routing Mode'), findsOneWidget);
    expect(find.text('Routing Default Action'), findsOneWidget);
    expect(find.text('Routing Global Action'), findsOneWidget);
    expect(find.text('Routing Rule Count'), findsOneWidget);
    expect(find.text('Routing Policy Group Count'), findsOneWidget);
    expect(find.text('Routing Match Constraints'), findsOneWidget);
    expect(find.text('Stub-only'), findsWidgets);
    expect(find.text('Shell-grade only'), findsWidgets);
    expect(find.text('${selected.serverHost}:${selected.serverPort}'),
        findsWidgets);
    expect(find.text('${selected.routing.rules.length}'), findsWidgets);
    expect(find.text('${selected.routing.policyGroups.length}'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late cached snapshot does not overwrite live profile readiness',
      (WidgetTester tester) async {
    await _setDesktopSurface(tester);
    final localState = _DelayedReadLocalStateStore();
    final services = _buildServices(localStateOverride: localState);
    final selected = services.profileStore.selectedProfile!;

    await services.profileSecrets.saveTrojanPassword(
      profileId: selected.id,
      password: 'secret',
    );
    services.profileStore.upsertProfile(
      selected.copyWith(hasStoredPassword: true),
    );
    await localState.write(
      'client.readiness.last-known.${selected.id}',
      jsonEncode(
        ReadinessReport.fromChecks(
          const <ReadinessCheck>[
            ReadinessCheck(
              domain: ReadinessDomain.config,
              level: ReadinessLevel.blocked,
              summary: 'stale invalid config snapshot',
              detail: 'stale snapshot should not override live readiness',
              action: ReadinessAction.openProfiles,
              actionLabel: 'Open Profiles',
            ),
          ],
          generatedAt: DateTime.now().subtract(const Duration(minutes: 10)),
        ).toJson(),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProfilesPage(services: services)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.text('Readiness: Ready with warnings'), findsOneWidget);
    expect(find.textContaining('Readiness source: Live check'), findsOneWidget);
    expect(find.text('Readiness: Blocked'), findsNothing);
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
    expect(find.textContaining('Readiness source:'), findsOneWidget);
    expect(
      find.textContaining('Check server host / server port / local SOCKS port'),
      findsWidgets,
    );

    final blockedButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Connect Test Blocked'),
    );
    expect(blockedButton.onPressed, isNull);

    expect(
        services.controller.status.phase, ClientConnectionPhase.disconnected);
    expect(find.textContaining('Recommended next step: Open Profiles'),
        findsOneWidget);
  });

  testWidgets(
      'primary connect preflight shows blocked reason + next action copy',
      (WidgetTester tester) async {
    await _setDesktopSurface(tester);
    final services = _buildServices(controllerOverride: _SlowHealthController());
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

    await tester
        .tap(find.widgetWithText(FilledButton, 'Connect Test (stub path)'));
    await tester.pump(const Duration(milliseconds: 360));

    expect(
      find.textContaining(
        'Connect blocked: Check server host / server port / local SOCKS port before connecting.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Next action: Open Profiles'), findsOneWidget);
    expect(services.controller.status.phase, ClientConnectionPhase.disconnected);
  });

  testWidgets(
      'quick connect preflight shows blocked reason + next action copy',
      (WidgetTester tester) async {
    await _setDesktopSurface(tester);
    final services = _buildServices(controllerOverride: _SlowHealthController());
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

    final quickConnectButton =
        find.widgetWithText(FilledButton, 'Quick Connect');
    await tester.ensureVisible(quickConnectButton);
    await tester.tap(quickConnectButton);
    await tester.pump(const Duration(milliseconds: 360));

    expect(
      find.textContaining(
        'Connect blocked: Check server host / server port / local SOCKS port before connecting.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Next action: Open Profiles'), findsOneWidget);
    expect(services.controller.status.phase, ClientConnectionPhase.disconnected);
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
    expect(
      find.widgetWithText(FilledButton, 'Connect Test (stub path)'),
      findsOneWidget,
    );
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

    final troubleshootingButtons = find.widgetWithText(
      OutlinedButton,
      'Open Troubleshooting',
    );
    expect(troubleshootingButtons, findsAtLeastNWidgets(1));

    await tester.tap(troubleshootingButtons.first);
    await tester.pump();

    expect(openedAdvanced, isTrue);
  });

  testWidgets('stale connected profile steers primary CTA to troubleshooting',
      (WidgetTester tester) async {
    await _setDesktopSurface(tester);
    var openedAdvanced = false;
    final services = _buildServices(
      controllerOverride: _StaleConnectedController(),
    );
    final selected = services.profileStore.selectedProfile!;

    await services.profileSecrets.saveTrojanPassword(
      profileId: selected.id,
      password: 'secret',
    );
    services.profileStore.upsertProfile(
      selected.copyWith(hasStoredPassword: true),
    );

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

    expect(find.text('Action safety'), findsOneWidget);
    expect(find.text('Revalidate before changing state'), findsOneWidget);
    expect(find.text('Revalidate in Troubleshooting'), findsOneWidget);
    expect(
        find.textContaining('Open Troubleshooting to revalidate the runtime'),
        findsOneWidget);
    expect(find.textContaining('disconnect and reconnect'), findsOneWidget);

    await tester.tap(find.text('Revalidate in Troubleshooting'));
    await tester.pump();

    expect(openedAdvanced, isTrue);
  });

  testWidgets('connect feedback stays truthful on stub posture',
      (WidgetTester tester) async {
    await _setDesktopSurface(tester);
    final services = _buildServices();
    final selected = services.profileStore.selectedProfile!;

    await services.profileSecrets.saveTrojanPassword(
      profileId: selected.id,
      password: 'secret',
    );
    services.profileStore.upsertProfile(
      selected.copyWith(hasStoredPassword: true),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProfilesPage(services: services)),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester
        .tap(find.widgetWithText(FilledButton, 'Connect Test (stub path)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();

    expect(find.textContaining('Shell validation is ready'), findsOneWidget);
  });

  testWidgets('profiles page surfaces safe mode and quarantine banner',
      (WidgetTester tester) async {
    await _setDesktopSurface(tester);
    final services = _buildServices(controllerOverride: _SafeModeController());
    final selected = services.profileStore.selectedProfile!;

    await services.profileSecrets.saveTrojanPassword(
      profileId: selected.id,
      password: 'secret',
    );
    services.profileStore.upsertProfile(
      selected.copyWith(hasStoredPassword: true),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProfilesPage(services: services)),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.textContaining('Safe Mode active'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Quarantined candidate:'),
      findsOneWidget,
    );
  });

  testWidgets(
      'disconnecting stop-pending profile gates primary action to troubleshooting',
      (WidgetTester tester) async {
    await _setDesktopSurface(tester);
    var openedAdvanced = false;
    final services = _buildServices(
      controllerOverride: _StaleConnectedController(),
    );
    final selected = services.profileStore.selectedProfile!;

    await services.profileSecrets.saveTrojanPassword(
      profileId: selected.id,
      password: 'secret',
    );
    services.profileStore.upsertProfile(
      selected.copyWith(hasStoredPassword: true),
    );

    final controller = services.controller as _StaleConnectedController;
    controller.statusOverride = ClientConnectionStatus(
      phase: ClientConnectionPhase.disconnecting,
      message: 'Disconnecting current session...',
      updatedAt: DateTime.now(),
      activeProfileId: 'sample-hk-1',
    );
    controller.sessionOverride = ControllerRuntimeSession(
      isRunning: true,
      updatedAt: DateTime.now().subtract(const Duration(seconds: 10)),
      phase: ControllerRuntimePhase.alive,
      stopRequested: true,
      stopRequestedAt: DateTime.now().subtract(const Duration(seconds: 5)),
      expectedLocalSocksPort: 10808,
    );

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

    expect(find.text('Action safety'), findsOneWidget);
    expect(find.text('Connect timeline'), findsOneWidget);
    expect(find.textContaining('Current stage: alive'), findsOneWidget);
    expect(find.text('Wait for exit confirmation'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Open Troubleshooting'),
        findsOneWidget);
    expect(
        find.textContaining(
            'Primary state-changing action is temporarily withheld'),
        findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Open Troubleshooting'));
    await tester.pump();

    expect(openedAdvanced, isTrue);
  });
}
