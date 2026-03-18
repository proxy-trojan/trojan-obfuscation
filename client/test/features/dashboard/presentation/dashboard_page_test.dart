import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/controller/application/client_controller_api.dart';
import 'package:trojan_pro_client/features/controller/application/fake_client_controller.dart';
import 'package:trojan_pro_client/features/controller/domain/client_connection_status.dart';
import 'package:trojan_pro_client/features/controller/domain/client_controller_event.dart';
import 'package:trojan_pro_client/features/controller/domain/controller_command_result.dart';
import 'package:trojan_pro_client/features/controller/domain/controller_runtime_config.dart';
import 'package:trojan_pro_client/features/controller/domain/controller_runtime_health.dart';
import 'package:trojan_pro_client/features/controller/domain/controller_runtime_session.dart';
import 'package:trojan_pro_client/features/controller/domain/controller_telemetry_snapshot.dart';
import 'package:trojan_pro_client/features/controller/domain/last_runtime_failure_summary.dart';
import 'package:trojan_pro_client/features/dashboard/presentation/dashboard_page.dart';
import 'package:trojan_pro_client/features/diagnostics/application/diagnostics_export_service.dart';
import 'package:trojan_pro_client/features/readiness/application/readiness_service.dart';
import 'package:trojan_pro_client/features/packaging/application/packaging_export_service.dart';
import 'package:trojan_pro_client/features/packaging/application/packaging_store.dart';
import 'package:trojan_pro_client/features/profiles/application/profile_portability_service.dart';
import 'package:trojan_pro_client/features/profiles/application/profile_secrets_service.dart';
import 'package:trojan_pro_client/features/profiles/application/profile_serialization.dart';
import 'package:trojan_pro_client/features/profiles/application/profile_store.dart';
import 'package:trojan_pro_client/features/profiles/domain/client_profile.dart';
import 'package:trojan_pro_client/features/settings/application/settings_serialization.dart';
import 'package:trojan_pro_client/features/settings/application/settings_store.dart';
import 'package:trojan_pro_client/platform/services/memory_diagnostics_file_exporter.dart';
import 'package:trojan_pro_client/platform/services/memory_local_state_store.dart';
import 'package:trojan_pro_client/platform/services/service_registry.dart';
import 'package:trojan_pro_client/platform/secure_storage/memory_secure_storage.dart';

class _TestLifecycleController extends ClientControllerApi {
  ClientConnectionStatus _status = ClientConnectionStatus.disconnected();
  String? lastConnectedProfileId;

  @override
  ClientConnectionStatus get status => _status;

  set statusForTest(ClientConnectionStatus value) {
    _status = value;
    notifyListeners();
  }

  @override
  List<ClientControllerEvent> get recentEvents =>
      const <ClientControllerEvent>[];

  @override
  ControllerTelemetrySnapshot get telemetry => ControllerTelemetrySnapshot(
        backendKind: 'test-controller',
        backendVersion: 'test',
        capabilities: const <String>['connect', 'disconnect'],
        lastUpdatedAt: DateTime.parse('2026-03-13T00:00:00.000Z'),
      );

  @override
  ControllerRuntimeConfig get runtimeConfig => const ControllerRuntimeConfig(
        mode: 'stubbed-local-boundary',
        endpointHint: 'local-controller://test',
        enableVerboseTelemetry: true,
      );

  @override
  ControllerRuntimeSession get session => ControllerRuntimeSession(
        isRunning: _status.phase == ClientConnectionPhase.connected,
        updatedAt: DateTime.now(),
        phase: _status.phase == ClientConnectionPhase.connected
            ? ControllerRuntimePhase.sessionReady
            : ControllerRuntimePhase.stopped,
      );

  @override
  LastRuntimeFailureSummary? get lastRuntimeFailure => null;

  @override
  Future<ControllerRuntimeHealth> checkHealth() async {
    return ControllerRuntimeHealth(
      level: ControllerRuntimeHealthLevel.healthy,
      summary: 'test controller healthy',
      updatedAt: DateTime.parse('2026-03-13T00:00:00.000Z'),
    );
  }

  @override
  Future<ControllerCommandResult> connect(ClientProfile profile) async {
    lastConnectedProfileId = profile.id;
    _status = ClientConnectionStatus(
      phase: ClientConnectionPhase.connected,
      message: 'Connected for ${profile.name}.',
      updatedAt: DateTime.now(),
      activeProfileId: profile.id,
    );
    notifyListeners();
    return ControllerCommandResult(
      commandId: 'test-connect',
      accepted: true,
      completedAt: DateTime.now(),
      summary: 'Connected for ${profile.name}.',
    );
  }

  @override
  Future<ControllerCommandResult> disconnect() async {
    _status = ClientConnectionStatus.disconnected();
    notifyListeners();
    return ControllerCommandResult(
      commandId: 'test-disconnect',
      accepted: true,
      completedAt: DateTime.now(),
      summary: 'Disconnected.',
    );
  }
}

Future<void> _setDesktopSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1600, 1400));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });
}

Future<void> _showDashboard(
  WidgetTester tester, {
  required ClientServiceRegistry services,
  VoidCallback? onOpenSettings,
}) async {
  await _setDesktopSurface(tester);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DashboardPage(
          services: services,
          onOpenSettings: onOpenSettings,
        ),
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

ClientServiceRegistry _buildServices({ClientControllerApi? controller}) {
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
  final resolvedController = controller ?? FakeClientController();

  final packagingExport = PackagingExportService(
    packagingStore: packagingStore,
    fileExporter: diagnosticsExporter,
  );
  final readiness = ReadinessService(
    profileStore: profileStore,
    profileSecrets: profileSecrets,
    secureStorage: secureStorage,
    controller: resolvedController,
  );

  final diagnostics = DiagnosticsExportService(
    profileStore: profileStore,
    profilePortability: profilePortability,
    settingsStore: settingsStore,
    packagingStore: packagingStore,
    controller: resolvedController,
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
    controller: resolvedController,
    readiness: readiness,
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
    expect(find.text('Problem Report'), findsWidgets);
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

  testWidgets('dashboard gates connect when readiness is blocked',
      (WidgetTester tester) async {
    final services = _buildServices();
    final profile = services.profileStore.selectedProfile!;
    await services.profileSecrets.saveTrojanPassword(
      profileId: profile.id,
      password: 'secret',
    );
    services.profileStore.upsertProfile(
      profile.copyWith(
        hasStoredPassword: true,
        serverHost: '',
      ),
    );

    await _showDashboard(tester, services: services);
    await tester.pumpAndSettle();

    expect(find.text('Connect blocked'), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'Connect now'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Open Profiles'), findsWidgets);
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

  testWidgets('retry now uses the active profile even when selection changed',
      (WidgetTester tester) async {
    final controller = _TestLifecycleController();
    final services = _buildServices(controller: controller);
    final first = services.profileStore.selectedProfile!;
    final second = services.profileStore.profiles[1];
    await services.profileSecrets.saveTrojanPassword(
      profileId: first.id,
      password: 'secret-first',
    );
    services.profileStore.upsertProfile(first.copyWith(hasStoredPassword: true));
    services.profileStore.selectProfile(second.id);
    controller.statusForTest = ClientConnectionStatus(
      phase: ClientConnectionPhase.error,
      message: 'Runtime session exited with code 7.',
      updatedAt: DateTime.now(),
      activeProfileId: first.id,
    );

    await _showDashboard(tester, services: services);

    final retryFinder = find.widgetWithText(FilledButton, 'Retry now');
    expect(retryFinder, findsOneWidget);
    await tester.ensureVisible(retryFinder);
    await tester.pump();

    await tester.tap(retryFinder);
    await tester.pump();

    expect(controller.lastConnectedProfileId, first.id);
    expect(controller.status.activeProfileId, first.id);
    expect(controller.status.phase, ClientConnectionPhase.connected);
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

  testWidgets('shows recent desktop activation when duplicate launch focuses window',
      (WidgetTester tester) async {
    final services = _buildServices();
    await services.desktopLifecycle.recordExternalActivation(
      source: 'secondary-launch-focus-ipc',
    );

    await _showDashboard(
      tester,
      services: services,
      onOpenSettings: () {},
    );

    expect(find.text('Recent desktop activation'), findsOneWidget);
    expect(
      find.text('Another launch focused this existing window'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Single-instance mitigation is working'),
      findsOneWidget,
    );
    expect(find.text('Single-instance guard active'), findsOneWidget);
    expect(find.text('Review desktop behavior'), findsOneWidget);
  });

  testWidgets('recent desktop activation can be dismissed',
      (WidgetTester tester) async {
    final services = _buildServices();
    await services.desktopLifecycle.recordExternalActivation(
      source: 'secondary-launch-focus-ipc',
    );

    await _showDashboard(tester, services: services);
    expect(find.text('Recent desktop activation'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Dismiss'));
    await tester.pump();

    expect(find.text('Recent desktop activation'), findsNothing);
  });

  testWidgets('recent desktop activation can route user to desktop settings',
      (WidgetTester tester) async {
    final services = _buildServices();
    var openedSettings = false;
    await services.desktopLifecycle.recordExternalActivation(
      source: 'secondary-launch-focus-ipc',
    );

    await _showDashboard(
      tester,
      services: services,
      onOpenSettings: () {
        openedSettings = true;
      },
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Review desktop behavior'));
    await tester.pump();

    expect(openedSettings, isTrue);
  });
}
