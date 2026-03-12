enum PackagingExportStatus {
  idle,
  running,
  succeeded,
  failed,
}

class PackagingExportRecord {
  const PackagingExportRecord({
    required this.startedAt,
    required this.status,
    this.finishedAt,
    this.manifestTarget,
    this.metadataTarget,
    this.rollbackPlanTarget,
    this.error,
  });

  final DateTime startedAt;
  final DateTime? finishedAt;
  final PackagingExportStatus status;
  final String? manifestTarget;
  final String? metadataTarget;
  final String? rollbackPlanTarget;
  final String? error;

  PackagingExportRecord copyWith({
    DateTime? startedAt,
    DateTime? finishedAt,
    PackagingExportStatus? status,
    String? manifestTarget,
    String? metadataTarget,
    String? rollbackPlanTarget,
    String? error,
  }) {
    return PackagingExportRecord(
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      status: status ?? this.status,
      manifestTarget: manifestTarget ?? this.manifestTarget,
      metadataTarget: metadataTarget ?? this.metadataTarget,
      rollbackPlanTarget: rollbackPlanTarget ?? this.rollbackPlanTarget,
      error: error ?? this.error,
    );
  }
}
