import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/controller/application/fake_client_controller.dart';
import 'package:trojan_pro_client/features/diagnostics/application/diagnostics_export_service.dart';
import 'package:trojan_pro_client/features/diagnostics/presentation/diagnostics_page.dart';
import 'package:trojan_pro_client/features/packaging/application/packaging_export_service.dart';
import 'package:trojan_pro_client/features/packaging/application/packaging_store.dart';
import 'package:trojan_pro_client/features/profiles/application/profile_portability_service.dart';
import 'package:trojan_pro_client/features/profiles/application/profile_secrets_service.dart';
import 'package:trojan_pro_client/features/profiles/application/profile_serialization.dart';
import 'package:trojan_pro_client/features/profiles/application/profile_store.dart';
import 'package:trojan_pro_client/features/settings/application/settings_serialization.dart';
import 'package:trojan_pro_client/features/settings/application/settings_store.dart';
import 'package:trojan_pro_client/platform/services/diagnostics_file_exporter.dart';
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

class _FailingDiagnosticsFileExporter implements DiagnosticsFileExporter {
  @override
  String get backendName => 'failing-test-exporter';

  @override
  Future<String> exportJson({
    required String suggestedFileName,
    required String jsonContent,
  }) async {
    throw StateError('permission denied for diagnostics export');
  }
}

ClientServiceRegistry _buildServices({DiagnosticsFileExporter? exporter}) {
  final localState = MemoryLocalStateStore();
  final secureStorage = MemorySecureStorage();
  final diagnosticsExporter = exporter ?? MemoryDiagnosticsFileExporter();
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
      find.widgetWithText(OutlinedButton, 'Export bundle'),
    );
    expect(exportButtonBefore.onPressed, isNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Generate preview'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final exportButtonAfter = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Export bundle'),
    );
    expect(exportButtonAfter.onPressed, isNotNull);
    expect(find.text('Preview excerpt'), findsOneWidget);
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

    await tester.tap(find.widgetWithText(FilledButton, 'Generate preview'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.widgetWithText(OutlinedButton, 'Export bundle'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Support bundle exported'), findsOneWidget);
    expect(find.textContaining('Last export target:'), findsOneWidget);
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

    await tester.tap(find.widgetWithText(FilledButton, 'Generate preview'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.widgetWithText(OutlinedButton, 'Export bundle'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Export / OS:'), findsOneWidget);
    expect(find.textContaining('permission denied'), findsOneWidget);
  });
}
