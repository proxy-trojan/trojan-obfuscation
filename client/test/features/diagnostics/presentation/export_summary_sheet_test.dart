import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/controller/domain/runtime_posture.dart';
import 'package:trojan_pro_client/features/diagnostics/domain/export_summary_snapshot.dart';
import 'package:trojan_pro_client/features/diagnostics/presentation/export_summary_sheet.dart';

void main() {
  testWidgets('shows runtime posture and recovery hints before export',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ExportSummarySheet(
            runtimePostureLabel: 'Runtime-true',
            recoveryHint: 'No active rollback',
          ),
        ),
      ),
    );

    expect(find.textContaining('Runtime-true'), findsOneWidget);
    expect(find.textContaining('No active rollback'), findsOneWidget);
  });

  testWidgets('shows support-bundle posture warning when runtime is stub-only',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExportSummarySheet.fromRuntimePosture(
            posture: describeRuntimePosture(
              runtimeMode: 'stubbed-local-boundary',
              backendKind: 'fake-shell-controller',
            ),
            recoveryHint: 'Safe mode rollback is active.',
            secretStorageSummary: 'Temporary session-only fallback',
            secretStorageMode: 'Session-only',
          ),
        ),
      ),
    );

    expect(find.textContaining('Shell-grade only'), findsOneWidget);
    expect(
      find.textContaining('support triage only'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Secret storage: Temporary session-only fallback'),
      findsOneWidget,
    );
    expect(find.textContaining('Storage mode: Session-only'), findsOneWidget);
  });

  testWidgets('renders from snapshot payload with unified usage hint',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExportSummarySheet.fromSnapshot(
            const ExportSummarySnapshot(
              runtimePostureLabel: 'Runtime-true',
              evidenceGrade: 'Evidence-grade',
              runtimeTruth: 'Live',
              recoveryHint: 'No recovery action is needed.',
              usageHint:
                  'Use as runtime-true evidence when posture remains evidence-grade.',
              secretStorageSummary: 'Secure storage ready',
              secretStorageMode: 'Secure persistent',
              secretStoragePersistent: true,
              secretStorageSecure: true,
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('Runtime-true'), findsOneWidget);
    expect(
      find.textContaining('Use as runtime-true evidence when posture remains evidence-grade.'),
      findsOneWidget,
    );
    expect(find.textContaining('Secret storage: Secure storage ready'),
        findsOneWidget);
    expect(find.textContaining('Storage mode: Secure persistent'),
        findsOneWidget);
  });
}
