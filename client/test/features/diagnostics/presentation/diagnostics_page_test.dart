import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/controller/application/client_controller_api.dart';
import 'package:trojan_pro_client/features/controller/application/fake_client_controller.dart';
import 'package:trojan_pro_client/features/controller/domain/controller_runtime_config.dart';
import 'package:trojan_pro_client/features/controller/domain/controller_runtime_session.dart';
import 'package:trojan_pro_client/features/controller/domain/controller_telemetry_snapshot.dart';
import 'package:trojan_pro_client/features/diagnostics/application/diagnostics_export_service.dart';
import 'package:trojan_pro_client/features/diagnostics/presentation/diagnostics_page.dart';
import 'package:trojan_pro_client/features/packaging/application/packaging_export_service.dart';
import 'package:trojan_pro_client/features/packaging/application/packaging_store.dart';
import 'package:trojan_pro_client/features/profiles/application/profile_portability_service.dart';
import 'package:trojan_pro_client/features/profiles/application/profile_secrets_service.dart';
import 'package:trojan_pro_client/features/profiles/application/profile_serialization.dart';
import 'package:trojan_pro_client/features/profiles/application/profile_store.dart';
import 'package:trojan_pro_client/features/readiness/application/readiness_service.dart';
import 'package:trojan_pro_client/features/settings/application/settings_serialization.dart';
import 'package:trojan_pro_client/features/settings/application/settings_store.dart';
import 'package:trojan_pro_client/platform/services/diagnostics_file_exporter.dart';
import 'package:trojan_pro_client/platform/services/memory_diagnostics_file_exporter.dart';
import 'package:trojan_pro_client/platform/services/memory_local_state_store.dart';
import 'package:trojan_pro_client/platform/services/service_registry.dart';
import 'package:trojan_pro_client/platform/secure_storage/memory_secure_storage.dart';

Future<void> _setDesktopSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1600, 1800));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });
}

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

  @override
  ControllerRuntimeSession get session => ControllerRuntimeSession(
        isRunning: true,
        updatedAt: DateTime.now().subtract(const Duration(seconds: 8)),
        phase: ControllerRuntimePhase.sessionReady,
        pid: 4242,
        configProvenance: 'managed-runtime://sample-hk-1',
      );
}

class _FailingDiagnosticsFileExporter implements DiagnosticsFileExporter {
  @override
  String get backendName => 'failing-test-exporter';

  @override
  Future<String> exportText({
    required String fileName,
    required String contents,
  }) async {
    throw StateError('permission denied for diagnostics export');
  }
}

class _StoppingController extends FakeClientController {
  @override
  ControllerRuntimeSession get session => ControllerRuntimeSession(
        isRunning: true,
        updatedAt: DateTime.now().subtract(const Duration(seconds: 12)),
        phase: ControllerRuntimePhase.alive,
        stopRequested: true,
        stopRequestedAt: DateTime.now().subtract(const Duration(seconds: 6)),
        pid: 4242,
      );
}

ClientServiceRegistry _buildServices({
  DiagnosticsFileExporter? exporter,
  ClientControllerApi? controllerOverride,
}) {
  final localState = MemoryLocalStateStore();
  final secureStorage = MemorySecureStorage();
  final diagnosticsExporter = exporter ?? MemoryDiagnosticsFileExporter();
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
  testWidgets('shows runtime-proof export path on evidence-grade posture',
      (WidgetTester tester) async {
    await _setDesktopSurface(tester);
    final services =
        _buildServices(controllerOverride: _RuntimeTrueController());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DiagnosticsPage(services: services),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Current evidence grade: Evidence-grade'),
      findsOneWidget,
    );
    expect(find.text('Runtime-proof artifact available'), findsOneWidget);
    expect(find.text('How to use runtime-proof artifacts'), findsOneWidget);
    expect(find.text('Runtime truth & recovery'), findsOneWidget);
    expect(find.text('Current runtime truth: Live'), findsOneWidget);
    expect(find.text('Needs attention: No'), findsOneWidget);
    expect(find.textContaining('runtime-true evidence'), findsOneWidget);

    await tester
        .tap(find.widgetWithText(FilledButton, 'Generate support preview'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.widgetWithText(OutlinedButton, 'Export runtime-proof artifact'),
      findsOneWidget,
    );
  });

  testWidgets('shows support bundle summary before export',
      (WidgetTester tester) async {
    await _setDesktopSurface(tester);
    final services = _buildServices();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DiagnosticsPage(services: services),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Before you export a support bundle'), findsOneWidget);
    expect(
      find.text('Current evidence grade: Shell-grade only'),
      findsOneWidget,
    );
    expect(
      find.text('Runtime-proof artifact unavailable on current posture'),
      findsOneWidget,
    );
    expect(
      find.text('How to use support bundles on this posture'),
      findsOneWidget,
    );
    expect(find.text('Runtime truth & recovery'), findsOneWidget);
    expect(find.text('Current runtime truth: Residual snapshot'), findsOneWidget);
    expect(find.text('Needs attention: Yes'), findsOneWidget);
    expect(find.textContaining('support context rather than proof'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Export runtime-proof artifact'),
      findsNothing,
    );
    expect(find.text('Includes'), findsOneWidget);
    expect(find.text('Does not include'), findsOneWidget);
    expect(find.textContaining('raw Trojan password'), findsOneWidget);
  });

  testWidgets('enables export only after preview generation',
      (WidgetTester tester) async {
    await _setDesktopSurface(tester);
    final services = _buildServices();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DiagnosticsPage(services: services),
        ),
      ),
    );
    await tester.pump();

    final exportButtonBefore = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Export support bundle'),
    );
    expect(exportButtonBefore.onPressed, isNull);

    await tester
        .tap(find.widgetWithText(FilledButton, 'Generate support preview'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final exportButtonAfter = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Export support bundle'),
    );
    expect(exportButtonAfter.onPressed, isNotNull);
    expect(find.text('Preview excerpt'), findsOneWidget);
    final preview = await services.diagnostics.buildPreviewBundle();
    expect(preview, contains('"runtimePosture"'));
    expect(preview, contains('"evidenceGrade": "Shell-grade only"'));
  });

  testWidgets('shows export success state after bundle write',
      (WidgetTester tester) async {
    await _setDesktopSurface(tester);
    final services = _buildServices();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DiagnosticsPage(services: services),
        ),
      ),
    );
    await tester.pump();

    await tester
        .tap(find.widgetWithText(FilledButton, 'Generate support preview'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Last captured export snapshot'), findsOneWidget);
    expect(find.textContaining('support preview captured Residual snapshot'),
        findsOneWidget);

    await tester
        .tap(find.widgetWithText(OutlinedButton, 'Export support bundle'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.textContaining('Last export target (support bundle):'),
      findsOneWidget,
    );
    expect(find.textContaining('support bundle captured Residual snapshot'),
        findsOneWidget);
  });

  testWidgets('stopping runtime shows exit confirmation warning',
      (WidgetTester tester) async {
    await _setDesktopSurface(tester);
    final services = _buildServices(controllerOverride: _StoppingController());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DiagnosticsPage(services: services),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Runtime truth & recovery'), findsOneWidget);
    expect(find.text('Current runtime truth: Stopping'), findsOneWidget);
    expect(find.text('Action safety'), findsOneWidget);
    expect(find.text('Wait for exit confirmation'), findsWidgets);
    expect(find.text('Exit confirmation pending'), findsOneWidget);
    expect(find.textContaining('Do not treat this runtime as fully closed yet'),
        findsWidgets);
    expect(find.text('Recommended right now: capture a support snapshot first'),
        findsOneWidget);
    expect(find.textContaining('Generate a support preview or export a support bundle'),
        findsOneWidget);
    expect(
      find.textContaining('This preserves the stop-pending evidence while it is still current.'),
      findsOneWidget,
    );
    expect(find.text('Preferred evidence action: Generate support preview'),
        findsOneWidget);
  });

  testWidgets('shows categorized export error guidance when export fails',
      (WidgetTester tester) async {
    await _setDesktopSurface(tester);
    final services =
        _buildServices(exporter: _FailingDiagnosticsFileExporter());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DiagnosticsPage(services: services),
        ),
      ),
    );
    await tester.pump();

    await tester
        .tap(find.widgetWithText(FilledButton, 'Generate support preview'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester
        .tap(find.widgetWithText(OutlinedButton, 'Export support bundle'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Failed to export diagnostics bundle'),
        findsOneWidget);
    expect(
      find.text('Detail: Bad state: permission denied for diagnostics export'),
      findsOneWidget,
    );
    expect(
        find.text('The support bundle could not be written'), findsOneWidget);
    expect(find.textContaining('Check the export target path'), findsOneWidget);
  });
}
