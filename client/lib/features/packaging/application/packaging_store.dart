import 'package:flutter/foundation.dart';

import '../../settings/domain/app_settings.dart';
import '../domain/desktop_package_status.dart';
import '../domain/packaging_export_record.dart';
import '../domain/release_manifest.dart';
import '../domain/update_metadata_snapshot.dart';
import '../domain/update_workflow_state.dart';
import 'packaging_dry_run_service.dart';

class PackagingStore extends ChangeNotifier {
  PackagingStore({UpdateChannel initialChannel = UpdateChannel.stable})
      : _state = UpdateWorkflowState.initial.copyWith(
          selectedChannel: initialChannel,
        ) {
    _dryRunService = PackagingDryRunService(packagingStore: this);
  }

  static const int _maxExportHistory = 5;

  late final PackagingDryRunService _dryRunService;
  UpdateWorkflowState _state;
  final List<PackagingExportRecord> _exportHistory = <PackagingExportRecord>[];

  final List<DesktopPackageStatus> _packageStatuses =
      const <DesktopPackageStatus>[
        DesktopPackageStatus(
          platform: DesktopPackagePlatform.windows,
          readiness: DesktopPackageReadiness.planned,
          notes: 'Windows installer/update workflow not scaffolded yet.',
        ),
        DesktopPackageStatus(
          platform: DesktopPackagePlatform.macos,
          readiness: DesktopPackageReadiness.planned,
          notes: 'macOS app bundle/notarization flow not scaffolded yet.',
        ),
        DesktopPackageStatus(
          platform: DesktopPackagePlatform.linux,
          readiness: DesktopPackageReadiness.scaffolded,
          notes: 'Linux desktop shell path exists; packaging workflow still missing.',
        ),
      ];

  UpdateWorkflowState get state => _state;

  List<DesktopPackageStatus> get packageStatuses =>
      List<DesktopPackageStatus>.unmodifiable(_packageStatuses);

  List<PackagingExportRecord> get exportHistory =>
      List<PackagingExportRecord>.unmodifiable(_exportHistory);

  ReleaseManifest buildReleaseManifest() => _dryRunService.buildSnapshot().manifest;

  UpdateMetadataSnapshot buildUpdateMetadataSnapshot() =>
      _dryRunService.buildSnapshot().updateMetadata;

  void syncUpdatePreferences({
    required UpdateChannel channel,
    required bool autoCheckForUpdates,
  }) {
    final nextState = _state.copyWith(
      selectedChannel: channel,
      updateChecksEnabled: autoCheckForUpdates,
    );
    if (nextState.selectedChannel == _state.selectedChannel &&
        nextState.updateChecksEnabled == _state.updateChecksEnabled) {
      return;
    }
    _state = nextState;
    notifyListeners();
  }

  void syncUpdateChannel(UpdateChannel channel) {
    syncUpdatePreferences(
      channel: channel,
      autoCheckForUpdates: _state.updateChecksEnabled,
    );
  }

  void markInstallerSkeletonReady() {
    if (_state.installerSkeletonReady) return;
    _state = _state.copyWith(
      installerSkeletonReady: true,
      lastCheckSummary: 'Packaging skeleton drafted; runtime validation still pending.',
    );
    notifyListeners();
  }

  void runDryRunSnapshot() {
    final result = _dryRunService.buildSnapshot();
    _state = _state.copyWith(lastCheckSummary: result.summary);
    notifyListeners();
  }

  void startExport() {
    _state = _state.copyWith(
      exportStatus: PackagingExportStatus.running,
      lastExport: PackagingExportRecord(
        startedAt: DateTime.now(),
        status: PackagingExportStatus.running,
      ),
    );
    notifyListeners();
  }

  void completeExport({
    required String manifestTarget,
    required String metadataTarget,
    required String rollbackPlanTarget,
  }) {
    final record = PackagingExportRecord(
      startedAt: _state.lastExport?.startedAt ?? DateTime.now(),
      finishedAt: DateTime.now(),
      status: PackagingExportStatus.succeeded,
      manifestTarget: manifestTarget,
      metadataTarget: metadataTarget,
      rollbackPlanTarget: rollbackPlanTarget,
    );
    _pushExportRecord(record);
    _state = _state.copyWith(
      exportStatus: PackagingExportStatus.succeeded,
      lastExport: record,
      lastCheckSummary: 'Packaging snapshots exported successfully.',
    );
    notifyListeners();
  }

  void failExport(Object error) {
    final record = PackagingExportRecord(
      startedAt: _state.lastExport?.startedAt ?? DateTime.now(),
      finishedAt: DateTime.now(),
      status: PackagingExportStatus.failed,
      error: error.toString(),
    );
    _pushExportRecord(record);
    _state = _state.copyWith(
      exportStatus: PackagingExportStatus.failed,
      lastExport: record,
      lastCheckSummary: 'Packaging snapshot export failed: $error',
    );
    notifyListeners();
  }

  void recordDryRunSummary(String summary) {
    _state = _state.copyWith(lastCheckSummary: summary);
    notifyListeners();
  }

  void _pushExportRecord(PackagingExportRecord record) {
    _exportHistory.insert(0, record);
    if (_exportHistory.length > _maxExportHistory) {
      _exportHistory.removeRange(_maxExportHistory, _exportHistory.length);
    }
  }
}
