import 'dart:convert';

import '../../../platform/services/diagnostics_file_exporter.dart';
import '../domain/rollback_plan_snapshot.dart';
import 'packaging_store.dart';

class PackagingExportResult {
  const PackagingExportResult({
    required this.manifestTarget,
    required this.metadataTarget,
    required this.rollbackPlanTarget,
  });

  final String manifestTarget;
  final String metadataTarget;
  final String rollbackPlanTarget;
}

class PackagingExportService {
  const PackagingExportService({
    required PackagingStore packagingStore,
    required DiagnosticsFileExporter fileExporter,
  })  : _packagingStore = packagingStore,
        _fileExporter = fileExporter;

  final PackagingStore _packagingStore;
  final DiagnosticsFileExporter _fileExporter;

  Future<PackagingExportResult> exportSnapshots() async {
    final manifest = _packagingStore.buildReleaseManifest();
    final metadata = _packagingStore.buildUpdateMetadataSnapshot();
    final rollbackPlan = RollbackPlanSnapshot(
      generatedAt: DateTime.now(),
      currentVersionLabel: manifest.versionLabel,
      channel: manifest.channel.name,
      rollbackArtifactHint: '${manifest.artifactPrefix}-previous-stable',
      steps: const <String>[
        'Locate previous stable installer + manifest bundle.',
        'Disable update rollout for the affected channel.',
        'Re-point update metadata to the previous stable artifact set.',
        'Re-run client-side diagnostics/export smoke checks before resuming rollout.',
      ],
    );
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');

    final manifestTarget = await _fileExporter.exportText(
      fileName: 'release-manifest-$timestamp.json',
      contents: const JsonEncoder.withIndent('  ').convert(manifest.toJson()),
    );
    final metadataTarget = await _fileExporter.exportText(
      fileName: 'update-metadata-$timestamp.json',
      contents: const JsonEncoder.withIndent('  ').convert(metadata.toJson()),
    );
    final rollbackPlanTarget = await _fileExporter.exportText(
      fileName: 'rollback-plan-$timestamp.json',
      contents: const JsonEncoder.withIndent('  ').convert(rollbackPlan.toJson()),
    );

    return PackagingExportResult(
      manifestTarget: manifestTarget,
      metadataTarget: metadataTarget,
      rollbackPlanTarget: rollbackPlanTarget,
    );
  }
}
