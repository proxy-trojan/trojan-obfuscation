import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/controller/domain/controller_runtime_session.dart';
import 'package:trojan_pro_client/features/controller/domain/runtime_posture.dart';
import 'package:trojan_pro_client/features/diagnostics/domain/export_summary_snapshot.dart';
import 'package:trojan_pro_client/platform/secure_storage/secure_storage.dart';

void main() {
  test('builds export summary snapshot from runtime posture/session/storage', () {
    final posture = describeRuntimePosture(
      runtimeMode: 'stubbed-local-boundary',
      backendKind: 'fake-shell-controller',
    );
    final runtimeSession = ControllerRuntimeSession(
      isRunning: false,
      updatedAt: DateTime.parse('2026-04-20T08:00:00.000Z'),
      phase: ControllerRuntimePhase.failed,
    );
    const storageStatus = SecureStorageStatus(
      backendName: 'memory-only-stub',
      activeBackendName: 'memory-only-stub',
      isSecure: false,
      isPersistent: false,
    );

    final snapshot = ExportSummarySnapshot.fromContext(
      runtimePosture: posture,
      runtimeSession: runtimeSession,
      storageStatus: storageStatus,
    );

    expect(snapshot.runtimePostureLabel, 'Stub-only');
    expect(snapshot.evidenceGrade, 'Shell-grade only');
    expect(snapshot.runtimeTruth, 'Residual snapshot');
    expect(snapshot.recoveryHint, contains('leftover session state'));
    expect(snapshot.usageHint,
        contains('support context rather than proof of runtime-true execution'));
    expect(snapshot.secretStorageSummary, 'Session-only storage');
    expect(snapshot.secretStorageMode, 'Session-only');
    expect(snapshot.secretStoragePersistent, isFalse);
    expect(snapshot.secretStorageSecure, isFalse);
  });

  test('serializes export summary snapshot to stable payload fields', () {
    const snapshot = ExportSummarySnapshot(
      runtimePostureLabel: 'Runtime-true',
      evidenceGrade: 'Evidence-grade',
      runtimeTruth: 'Live',
      recoveryHint: 'No recovery action is needed.',
      usageHint: 'Use as runtime-true evidence when posture remains evidence-grade.',
      secretStorageSummary: 'Secure storage ready',
      secretStorageMode: 'Secure persistent',
      secretStoragePersistent: true,
      secretStorageSecure: true,
    );

    final json = snapshot.toJson();

    expect(json['runtimePostureLabel'], 'Runtime-true');
    expect(json['evidenceGrade'], 'Evidence-grade');
    expect(json['runtimeTruth'], 'Live');
    expect(json['recoveryHint'], 'No recovery action is needed.');
    expect(
      json['usageHint'],
      'Use as runtime-true evidence when posture remains evidence-grade.',
    );
    expect(json['secretStorageSummary'], 'Secure storage ready');
    expect(json['secretStorageMode'], 'Secure persistent');
    expect(json['secretStoragePersistent'], isTrue);
    expect(json['secretStorageSecure'], isTrue);
  });
}
