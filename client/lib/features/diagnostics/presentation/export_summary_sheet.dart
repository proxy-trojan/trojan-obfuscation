import 'package:flutter/material.dart';

import '../../controller/domain/runtime_posture.dart';

class ExportSummarySheet extends StatelessWidget {
  const ExportSummarySheet({
    super.key,
    required this.runtimePostureLabel,
    required this.recoveryHint,
    this.evidenceGradeLabel,
    this.evidenceNote,
    this.exportUsageHint,
    this.secretStorageSummary,
    this.secretStorageMode,
  });

  factory ExportSummarySheet.fromRuntimePosture({
    required RuntimePosture posture,
    required String recoveryHint,
    String? secretStorageSummary,
    String? secretStorageMode,
  }) {
    return ExportSummarySheet(
      runtimePostureLabel: posture.postureLabel,
      recoveryHint: recoveryHint,
      evidenceGradeLabel: posture.evidenceGradeLabel,
      evidenceNote: posture.evidenceGradeNote,
      exportUsageHint: posture.isRuntimeTrue
          ? 'Use this export for operator handoff and evidence packaging.'
          : 'Use this export for support triage only.',
      secretStorageSummary: secretStorageSummary,
      secretStorageMode: secretStorageMode,
    );
  }

  final String runtimePostureLabel;
  final String recoveryHint;
  final String? evidenceGradeLabel;
  final String? evidenceNote;
  final String? exportUsageHint;
  final String? secretStorageSummary;
  final String? secretStorageMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Export summary',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text('Runtime posture: $runtimePostureLabel'),
          if (evidenceGradeLabel != null) ...<Widget>[
            const SizedBox(height: 4),
            Text('Evidence grade: $evidenceGradeLabel'),
          ],
          const SizedBox(height: 4),
          Text('Recovery hint: $recoveryHint'),
          if (evidenceNote != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(evidenceNote!),
          ],
          if (exportUsageHint != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              exportUsageHint!,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
          if ((secretStorageSummary ?? '').isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'Secret storage: $secretStorageSummary',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if ((secretStorageMode ?? '').isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text('Storage mode: $secretStorageMode'),
            ],
          ],
        ],
      ),
    );
  }
}
