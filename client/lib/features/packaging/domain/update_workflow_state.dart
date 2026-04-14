import '../../settings/domain/app_settings.dart';
import 'packaging_export_record.dart';

class UpdateWorkflowState {
  const UpdateWorkflowState({
    required this.selectedChannel,
    required this.currentVersionLabel,
    required this.updateChecksEnabled,
    required this.lastCheckSummary,
    required this.rolloutPolicySummary,
    required this.releaseMetadataContractVersion,
    required this.lastUpdateCheckAt,
    required this.updateCheckStatusLabel,
    required this.installerSkeletonReady,
    required this.exportStatus,
    this.lastExport,
  });

  final UpdateChannel selectedChannel;
  final String currentVersionLabel;
  final bool updateChecksEnabled;
  final String lastCheckSummary;
  final String rolloutPolicySummary;
  final String releaseMetadataContractVersion;
  final DateTime? lastUpdateCheckAt;
  final String updateCheckStatusLabel;
  final bool installerSkeletonReady;
  final PackagingExportStatus exportStatus;
  final PackagingExportRecord? lastExport;

  UpdateWorkflowState copyWith({
    UpdateChannel? selectedChannel,
    String? currentVersionLabel,
    bool? updateChecksEnabled,
    String? lastCheckSummary,
    String? rolloutPolicySummary,
    String? releaseMetadataContractVersion,
    DateTime? lastUpdateCheckAt,
    String? updateCheckStatusLabel,
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
      releaseMetadataContractVersion:
          releaseMetadataContractVersion ?? this.releaseMetadataContractVersion,
      lastUpdateCheckAt: lastUpdateCheckAt ?? this.lastUpdateCheckAt,
      updateCheckStatusLabel:
          updateCheckStatusLabel ?? this.updateCheckStatusLabel,
      installerSkeletonReady:
          installerSkeletonReady ?? this.installerSkeletonReady,
      exportStatus: exportStatus ?? this.exportStatus,
      lastExport: lastExport ?? this.lastExport,
    );
  }

  static const UpdateWorkflowState initial = UpdateWorkflowState(
    selectedChannel: UpdateChannel.beta,
    currentVersionLabel: '1.4.0-beta.3',
    updateChecksEnabled: true,
    lastCheckSummary:
        'No update check has been executed in this shell environment yet.',
    rolloutPolicySummary:
        'Desktop-first staged rollout with stable/beta/nightly lanes.',
    releaseMetadataContractVersion: 'v0-draft',
    lastUpdateCheckAt: null,
    updateCheckStatusLabel: 'Not yet checked (stub only)',
    installerSkeletonReady: false,
    exportStatus: PackagingExportStatus.idle,
  );
}
