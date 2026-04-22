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
          rolloutPolicySummary: _rolloutPolicySummaryFor(initialChannel),
        ) {
    _dryRunService = PackagingDryRunService(packagingStore: this);
  }

  static const int _maxExportHistory = 5;

  late final PackagingDryRunService _dryRunService;
  UpdateWorkflowState _state;
  final List<PackagingExportRecord> _exportHistory = <PackagingExportRecord>[];

  // 不使用 const：列表内容在后续版本中可能被动态更新
  final List<DesktopPackageStatus> _packageStatuses = <DesktopPackageStatus>[
    const DesktopPackageStatus(
      platform: DesktopPackagePlatform.windows,
      readiness: DesktopPackageReadiness.scaffolded,
      notes:
          'Windows packaging lane exists and packaged smoke gate is wired in CI; runner-backed evidence should continue to accumulate.',
    ),
    const DesktopPackageStatus(
      platform: DesktopPackagePlatform.macos,
      readiness: DesktopPackageReadiness.scaffolded,
      notes:
          'macOS app packaging lane exists and packaged smoke gate is wired in CI; notarization/release confidence still needs ongoing evidence.',
    ),
    const DesktopPackageStatus(
      platform: DesktopPackagePlatform.linux,
      readiness: DesktopPackageReadiness.validated,
      notes:
          'Validated locally; packaged smoke gate is in place for the Linux bundle lane.',
    ),
  ];

  UpdateWorkflowState get state => _state;

  List<DesktopPackageStatus> get packageStatuses =>
      List<DesktopPackageStatus>.unmodifiable(_packageStatuses);

  List<PackagingExportRecord> get exportHistory =>
      List<PackagingExportRecord>.unmodifiable(_exportHistory);

  ReleaseManifest buildReleaseManifest() =>
      _dryRunService.buildSnapshot().manifest;

  UpdateMetadataSnapshot buildUpdateMetadataSnapshot() =>
      _dryRunService.buildSnapshot().updateMetadata;

  void syncUpdatePreferences({
    required UpdateChannel channel,
    required bool autoCheckForUpdates,
  }) {
    final nextState = _state.copyWith(
      selectedChannel: channel,
      updateChecksEnabled: autoCheckForUpdates,
      rolloutPolicySummary: _rolloutPolicySummaryFor(channel),
    );
    if (nextState.selectedChannel == _state.selectedChannel &&
        nextState.updateChecksEnabled == _state.updateChecksEnabled &&
        nextState.rolloutPolicySummary == _state.rolloutPolicySummary) {
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

  void runStubUpdateCheck() {
    final checkedAt = DateTime.now();
    final channel = _state.selectedChannel;
    _state = _state.copyWith(
      lastUpdateCheckAt: checkedAt,
      updateCheckStatusLabel: 'Stub only — no release feed wired yet',
      lastCheckSummary: _stubUpdateSummaryFor(channel),
      rolloutPolicySummary: _rolloutPolicySummaryFor(channel),
    );
    notifyListeners();
  }

  void markInstallerSkeletonReady() {
    if (_state.installerSkeletonReady) return;
    _state = _state.copyWith(
      installerSkeletonReady: true,
      lastCheckSummary:
          'Packaging skeleton drafted; release truth + packaged smoke gates are now part of the current stable posture.',
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

  static String _rolloutPolicySummaryFor(UpdateChannel channel) {
    return switch (channel) {
      UpdateChannel.stable =>
        'Stable lane is the default user-facing channel with the strongest rollout caution.',
      UpdateChannel.beta =>
        'Beta lane is opt-in for desktop testers and may move faster than stable.',
      UpdateChannel.nightly =>
        'Nightly lane is internal/fast-moving and should not be treated as support-ready.',
    };
  }

  static String _stubUpdateSummaryFor(UpdateChannel channel) {
    return 'Update check stub executed for ${channel.name}. No remote release feed is wired in v1.5.0 yet; use exported release metadata + packaging docs instead.';
  }
}
