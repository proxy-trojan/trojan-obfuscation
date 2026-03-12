import '../../settings/domain/app_settings.dart';
import 'packaging_export_record.dart';

class UpdateWorkflowState {
  const UpdateWorkflowState({
    required this.selectedChannel,
    required this.currentVersionLabel,
    required this.updateChecksEnabled,
    required this.lastCheckSummary,
    required this.rolloutPolicySummary,
    required this.installerSkeletonReady,
    required this.exportStatus,
    this.lastExport,
  });

  final UpdateChannel selectedChannel;
  final String currentVersionLabel;
  final bool updateChecksEnabled;
  final String lastCheckSummary;
  final String rolloutPolicySummary;
  final bool installerSkeletonReady;
  final PackagingExportStatus exportStatus;
  final PackagingExportRecord? lastExport;

  UpdateWorkflowState copyWith({
    UpdateChannel? selectedChannel,
    String? currentVersionLabel,
    bool? updateChecksEnabled,
    String? lastCheckSummary,
    String? rolloutPolicySummary,
    bool? installerSkeletonReady,
    PackagingExportStatus? exportStatus,
    PackagingExportRecord? lastExport,
  }) {
    return UpdateWorkflowState(
      selectedChannel: selectedChannel ?? this.selectedChannel,
      currentVersionLabel: currentVersionLabel ?? this.currentVersionLabel,
      updateChecksEnabled: updateChecksEnabled ?? this.updateChecksEnabled,
      lastCheckSummary: lastCheckSummary ?? this.lastCheckSummary,
      rolloutPolicySummary: rolloutPolicySummary ?? this.rolloutPolicySummary,
      installerSkeletonReady: installerSkeletonReady ?? this.installerSkeletonReady,
      exportStatus: exportStatus ?? this.exportStatus,
      lastExport: lastExport ?? this.lastExport,
    );
  }

  static const UpdateWorkflowState initial = UpdateWorkflowState(
    selectedChannel: UpdateChannel.stable,
    currentVersionLabel: 'client-shell-dev',
    updateChecksEnabled: true,
    lastCheckSummary: 'No update check has been executed in this shell environment yet.',
    rolloutPolicySummary: 'Desktop-first staged rollout with stable/beta/nightly lanes.',
    installerSkeletonReady: false,
    exportStatus: PackagingExportStatus.idle,
  );
}
