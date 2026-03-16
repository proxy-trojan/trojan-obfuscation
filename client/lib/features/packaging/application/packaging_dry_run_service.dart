import '../domain/release_manifest.dart';
import '../domain/update_metadata_snapshot.dart';
import 'packaging_store.dart';

class PackagingDryRunResult {
  const PackagingDryRunResult({
    required this.manifest,
    required this.updateMetadata,
    required this.summary,
  });

  final ReleaseManifest manifest;
  final UpdateMetadataSnapshot updateMetadata;
  final String summary;
}

class PackagingDryRunService {
  const PackagingDryRunService({required PackagingStore packagingStore})
      : _packagingStore = packagingStore;

  final PackagingStore _packagingStore;

  PackagingDryRunResult buildSnapshot() {
    final state = _packagingStore.state;
    final generatedAt = DateTime.now();
    final manifest = ReleaseManifest(
      versionLabel: state.currentVersionLabel,
      channel: state.selectedChannel,
      generatedAt: generatedAt,
      artifactPrefix: 'trojan-pro-client-${state.selectedChannel.name}',
      platforms: _packagingStore.packageStatuses,
      rollbackHint:
          'Retain previous stable manifest + installer metadata for one-click rollback.',
    );
    final metadata = UpdateMetadataSnapshot(
      generatedAt: generatedAt,
      channel: state.selectedChannel.name,
      updateChecksEnabled: state.updateChecksEnabled,
      currentVersionLabel: state.currentVersionLabel,
      manifestArtifactName: '${manifest.artifactPrefix}-manifest.json',
      contractVersion: state.releaseMetadataContractVersion,
      summary: state.lastCheckSummary,
    );

    return PackagingDryRunResult(
      manifest: manifest,
      updateMetadata: metadata,
      summary:
          'Dry-run snapshot built for ${state.selectedChannel.name} channel with ${_packagingStore.packageStatuses.length} platform targets.',
    );
  }
}
