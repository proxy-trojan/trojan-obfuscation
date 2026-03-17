import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/advanced/presentation/advanced_page.dart';
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
import 'package:trojan_pro_client/platform/services/app_runtime_error_store.dart';
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

ClientServiceRegistry _buildServices({
  AppRuntimeErrorStore? appRuntimeErrors,
}) {
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
  final runtimeErrors =
      appRuntimeErrors ?? AppRuntimeErrorStore(localStateStore: localState);

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
    appRuntimeErrors: runtimeErrors,
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
    appRuntimeErrors: runtimeErrors,
  );
}

void main() {
  testWidgets('shows support overview and problem report action',
      (WidgetTester tester) async {
    await _setDesktopSurface(tester);
    final services = _buildServices();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdvancedPage(services: services),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Troubleshooting Overview'), findsOneWidget);
    expect(find.text('What to try next'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Open Problem Report'),
      findsOneWidget,
    );
  });

  testWidgets('surfaces last uncaught app error in support overview',
      (WidgetTester tester) async {
    await _setDesktopSurface(tester);
    final appRuntimeErrors = AppRuntimeErrorStore();
    await appRuntimeErrors.record(
      source: 'zone_guard',
      error: StateError('unhandled packaging stub issue'),
      stackTrace: StackTrace.current,
    );
    final services = _buildServices(appRuntimeErrors: appRuntimeErrors);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdvancedPage(services: services),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Last uncaught app error'), findsOneWidget);
    expect(
      find.textContaining('unhandled packaging stub issue'),
      findsOneWidget,
    );
  });
}
