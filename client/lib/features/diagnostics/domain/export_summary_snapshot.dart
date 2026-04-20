import '../../controller/domain/controller_runtime_session.dart';
import '../../controller/domain/runtime_posture.dart';
import '../../../platform/secure_storage/secure_storage.dart';

class ExportSummarySnapshot {
  const ExportSummarySnapshot({
    required this.runtimePostureLabel,
    required this.evidenceGrade,
    required this.runtimeTruth,
    required this.recoveryHint,
    required this.usageHint,
    required this.secretStorageSummary,
    required this.secretStorageMode,
    required this.secretStoragePersistent,
    required this.secretStorageSecure,
  });

  factory ExportSummarySnapshot.fromContext({
    required RuntimePosture runtimePosture,
    required ControllerRuntimeSession runtimeSession,
    required SecureStorageStatus storageStatus,
  }) {
    return ExportSummarySnapshot(
      runtimePostureLabel: runtimePosture.postureLabel,
      evidenceGrade: runtimePosture.evidenceGradeLabel,
      runtimeTruth: runtimeSession.truth.label,
      recoveryHint: runtimeSession.recoveryGuidance,
      usageHint: runtimePosture.isRuntimeTrue
          ? 'Use as runtime-true evidence when posture remains evidence-grade.'
          : 'Treat as support context rather than proof of runtime-true execution.',
      secretStorageSummary: storageStatus.userFacingSummary,
      secretStorageMode: storageStatus.storageModeLabel,
      secretStoragePersistent: storageStatus.isPersistent,
      secretStorageSecure: storageStatus.isSecure,
    );
  }

  final String runtimePostureLabel;
  final String evidenceGrade;
  final String runtimeTruth;
  final String recoveryHint;
  final String usageHint;
  final String secretStorageSummary;
  final String secretStorageMode;
  final bool secretStoragePersistent;
  final bool secretStorageSecure;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'runtimePostureLabel': runtimePostureLabel,
      'evidenceGrade': evidenceGrade,
      'runtimeTruth': runtimeTruth,
      'recoveryHint': recoveryHint,
      'usageHint': usageHint,
      'secretStorageSummary': secretStorageSummary,
      'secretStorageMode': secretStorageMode,
      'secretStoragePersistent': secretStoragePersistent,
      'secretStorageSecure': secretStorageSecure,
    };
  }
}
