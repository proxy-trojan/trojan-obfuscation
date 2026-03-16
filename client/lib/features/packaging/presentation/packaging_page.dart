import 'package:flutter/material.dart';

import '../../../core/widgets/section_card.dart';
import '../../../platform/services/service_registry.dart';
import '../domain/desktop_package_status.dart';
import '../domain/packaging_export_record.dart';

class PackagingPage extends StatelessWidget {
  const PackagingPage({super.key, required this.services});

  final ClientServiceRegistry services;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        services.packagingStore,
        services.settingsStore,
      ]),
      builder: (BuildContext context, _) {
        final workflow = services.packagingStore.state;
        final packageStatuses = services.packagingStore.packageStatuses;
        final exportHistory = services.packagingStore.exportHistory;
        final manifest = services.packagingStore.buildReleaseManifest();
        final updateMetadata =
            services.packagingStore.buildUpdateMetadataSnapshot();

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SectionCard(
                title: 'Update Status',
                subtitle:
                    'See update posture and release readiness for this desktop client. Most users will only need this occasionally.',
                trailing: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    OutlinedButton(
                      onPressed: services
                              .settingsStore.settings.autoCheckForUpdates
                          ? () => services.packagingStore.runStubUpdateCheck()
                          : null,
                      child: const Text('Check for Updates (Stub)'),
                    ),
                    OutlinedButton(
                      onPressed: () => _exportPackagingSnapshots(context),
                      child: const Text('Export Snapshots'),
                    ),
                    FilledButton(
                      onPressed: () {
                        services.packagingStore.markInstallerSkeletonReady();
                        services.packagingStore.runDryRunSnapshot();
                      },
                      child: Text(
                        workflow.installerSkeletonReady
                            ? 'Skeleton Ready'
                            : 'Acknowledge Skeleton',
                      ),
                    ),
                  ],
                ),
                child: Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  children: <Widget>[
                    _kv('Current Version', workflow.currentVersionLabel),
                    _kv('Update Channel', workflow.selectedChannel.name),
                    _kv('Auto Update Checks',
                        workflow.updateChecksEnabled ? 'Enabled' : 'Disabled'),
                    _kv(
                        'Installer Skeleton',
                        workflow.installerSkeletonReady
                            ? 'Drafted'
                            : 'Not yet drafted'),
                    _kv('Update Check Status', workflow.updateCheckStatusLabel),
                    _kv(
                      'Last Update Check',
                      workflow.lastUpdateCheckAt?.toIso8601String() ?? 'never',
                    ),
                    _kv('Metadata Contract',
                        workflow.releaseMetadataContractVersion),
                    _kv('Export Status', workflow.exportStatus.name),
                    _kv('Rollout Policy', workflow.rolloutPolicySummary),
                    _kv('Last Summary', workflow.lastCheckSummary),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Release Snapshot',
                subtitle:
                    'What the product layer would hand to packaging/update automation.',
                child: Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  children: <Widget>[
                    _kv('Artifact Prefix', manifest.artifactPrefix),
                    _kv('Manifest Channel', manifest.channel.name),
                    _kv('Generated At', manifest.generatedAt.toIso8601String()),
                    _kv('Rollback Hint', manifest.rollbackHint),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Update Metadata Snapshot',
                subtitle:
                    'Draft metadata view for client-side update behavior.',
                child: Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  children: <Widget>[
                    _kv('Manifest Artifact',
                        updateMetadata.manifestArtifactName),
                    _kv('Channel', updateMetadata.channel),
                    _kv(
                        'Update Checks',
                        updateMetadata.updateChecksEnabled
                            ? 'Enabled'
                            : 'Disabled'),
                    _kv('Contract Version', updateMetadata.contractVersion),
                    _kv('Summary', updateMetadata.summary),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Export History',
                subtitle:
                    'Recent packaging export operations and their outcomes.',
                child: exportHistory.isEmpty
                    ? const Text('No packaging exports have been run yet.')
                    : Column(
                        children: exportHistory
                            .map((record) => _ExportHistoryRow(record: record))
                            .toList(),
                      ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Desktop Release Readiness',
                subtitle: 'Per-platform release readiness and notes.',
                child: Column(
                  children: packageStatuses
                      .map((status) => _PlatformPackageRow(status: status))
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),
              const SectionCard(
                title: 'Planned Workflow Skeleton',
                subtitle:
                    'Product-side delivery shape before CI/runtime validation exists.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('1. Build desktop artifacts per release channel.'),
                    SizedBox(height: 8),
                    Text(
                        '2. Produce installer/update metadata bundles and release manifests.'),
                    SizedBox(height: 8),
                    Text(
                        '3. Validate diagnostics/export/update surfaces in a desktop runtime.'),
                    SizedBox(height: 8),
                    Text(
                        '4. Roll out stable/beta/nightly lanes with explicit rollback posture.'),
                    SizedBox(height: 8),
                    Text(
                        '5. Treat update checks as stub-only until a real release feed is wired.'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportPackagingSnapshots(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    services.packagingStore.startExport();
    try {
      final result = await services.packagingExport.exportSnapshots();
      services.packagingStore.completeExport(
        manifestTarget: result.manifestTarget,
        metadataTarget: result.metadataTarget,
        rollbackPlanTarget: result.rollbackPlanTarget,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Exported packaging snapshots:\nmanifest=${result.manifestTarget}\nmetadata=${result.metadataTarget}\nrollback=${result.rollbackPlanTarget}',
          ),
        ),
      );
    } catch (error) {
      services.packagingStore.failExport(error);
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to export packaging snapshots: $error')),
      );
    }
  }

  Widget _kv(String label, String value) {
    return SizedBox(
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value),
        ],
      ),
    );
  }
}

class _ExportHistoryRow extends StatelessWidget {
  const _ExportHistoryRow({required this.record});

  final PackagingExportRecord record;

  @override
  Widget build(BuildContext context) {
    final icon = switch (record.status) {
      PackagingExportStatus.idle => Icons.schedule,
      PackagingExportStatus.running => Icons.sync,
      PackagingExportStatus.succeeded => Icons.check_circle,
      PackagingExportStatus.failed => Icons.error,
    };

    final summary = switch (record.status) {
      PackagingExportStatus.idle => 'Idle',
      PackagingExportStatus.running => 'Running export…',
      PackagingExportStatus.succeeded =>
        'manifest=${record.manifestTarget}\nmetadata=${record.metadataTarget}\nrollback=${record.rollbackPlanTarget}',
      PackagingExportStatus.failed => record.error ?? 'Unknown export failure',
    };

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(record.status.name),
      subtitle: Text(summary),
      trailing: Text(
        record.finishedAt?.toIso8601String() ??
            record.startedAt.toIso8601String(),
      ),
    );
  }
}

class _PlatformPackageRow extends StatelessWidget {
  const _PlatformPackageRow({required this.status});

  final DesktopPackageStatus status;

  @override
  Widget build(BuildContext context) {
    final icon = switch (status.readiness) {
      DesktopPackageReadiness.planned => Icons.schedule,
      DesktopPackageReadiness.scaffolded => Icons.construction,
      DesktopPackageReadiness.validated => Icons.verified,
    };

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(status.platform.name),
      subtitle: Text(status.notes),
      trailing: Text(status.readiness.name),
    );
  }
}
