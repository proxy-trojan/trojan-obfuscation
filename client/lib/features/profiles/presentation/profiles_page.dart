import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/widgets/section_card.dart';
import '../../../platform/services/service_registry.dart';
import '../../controller/domain/client_connection_status.dart';
import '../../controller/domain/runtime_posture.dart';
import '../../readiness/domain/readiness_refresh_fingerprint.dart';
import '../../readiness/domain/readiness_report.dart';
import '../../readiness/presentation/readiness_surface_controller.dart';
import '../domain/client_profile.dart';
import 'import_export_dialog.dart';
import 'profile_editor_dialog.dart';
import 'profile_secret_dialog.dart';

class ProfilesPage extends StatelessWidget {
  const ProfilesPage({
    super.key,
    required this.services,
    this.onOpenAdvanced,
    this.onOpenSettings,
  });

  final ClientServiceRegistry services;
  final ValueChanged<ReadinessAction>? onOpenAdvanced;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(
          <Listenable>[services.profileStore, services.controller]),
      builder: (BuildContext context, _) {
        final profiles = services.profileStore.profiles;
        final selected = services.profileStore.selectedProfile;
        final status = services.controller.status;

        final listSection = SectionCard(
          title: 'Profiles',
          subtitle: 'Desktop-first profile management shell.',
          trailing: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: () => _importProfileFromFile(context),
                icon: const Icon(Icons.folder_open),
                label: const Text('Import File'),
              ),
              OutlinedButton.icon(
                onPressed: () => _importProfile(context),
                icon: const Icon(Icons.file_upload),
                label: const Text('Import Text'),
              ),
              FilledButton.icon(
                onPressed: () => _createProfile(context),
                icon: const Icon(Icons.add),
                label: const Text('Create'),
              ),
            ],
          ),
          child: profiles.isEmpty
              ? const Text('No profiles yet.')
              : Column(
                  children: profiles
                      .map(
                        (profile) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            services.profileStore.selectedProfileId ==
                                    profile.id
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                          ),
                          title: Text(profile.name),
                          subtitle: Text(
                              '${profile.serverHost}:${profile.serverPort}'),
                          trailing: status.activeProfileId == profile.id &&
                                  status.phase ==
                                      ClientConnectionPhase.connected
                              ? const Icon(Icons.link, color: Colors.green)
                              : null,
                          onTap: () =>
                              services.profileStore.selectProfile(profile.id),
                        ),
                      )
                      .toList(),
                ),
        );

        final detailSection = selected == null
            ? const SectionCard(
                title: 'Profile Details',
                child: Text('Select or create a profile to inspect it.'),
              )
            : _SelectedProfileCard(
                services: services,
                selected: selected,
                status: status,
                onOpenAdvanced: onOpenAdvanced,
                onOpenSettings: onOpenSettings,
              );

        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final useStackedLayout = constraints.maxWidth < 900;
            return SingleChildScrollView(
              child: useStackedLayout
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        listSection,
                        const SizedBox(height: 16),
                        detailSection,
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(flex: 2, child: listSection),
                        const SizedBox(width: 16),
                        Expanded(flex: 3, child: detailSection),
                      ],
                    ),
            );
          },
        );
      },
    );
  }

  Future<void> _createProfile(BuildContext context) async {
    final profile = await showProfileEditorDialog(context);
    if (profile == null) return;
    services.profileStore.upsertProfile(profile);
  }

  Future<void> _importProfile(BuildContext context) async {
    final text = await showImportTextDialog(context);
    if (text == null || text.trim().isEmpty) return;
    if (!context.mounted) return;
    await _importProfileText(context, text.trim());
  }

  Future<void> _importProfileFromFile(BuildContext context) async {
    final inputPath = await showPathInputDialog(
      context,
      title: 'Import Profile From File',
      hintText: '/path/to/profile.json',
      confirmLabel: 'Load',
    );
    if (inputPath == null || inputPath.trim().isEmpty) return;

    if (!context.mounted) return;
    try {
      final file = File(inputPath.trim());
      final text = await file.readAsString();
      if (!context.mounted) return;
      await _importProfileText(context, text);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import file failed: $error')),
      );
    }
  }

  Future<void> _importProfileText(BuildContext context, String text) async {
    if (!context.mounted) return;
    try {
      final bundle = services.profilePortability.importBundle(text);
      final profile = bundle.profile;
      final hasStoredPassword =
          await services.profileSecrets.hasTrojanPassword(profile.id);
      services.profileStore.upsertProfile(
        profile.copyWith(hasStoredPassword: hasStoredPassword),
      );

      final needsPasswordHandoff =
          bundle.sourceDeviceHadStoredPassword && !hasStoredPassword;
      final bundleClaimsPasswordIncluded = bundle.trojanPasswordIncluded;
      final message = bundleClaimsPasswordIncluded
          ? 'Imported profile: ${profile.name}. Incoming bundle claimed embedded password material — ignored by design for safety.'
          : hasStoredPassword
              ? 'Imported profile: ${profile.name}. Local secure storage already has a password for this profile id.'
              : needsPasswordHandoff
                  ? 'Imported profile: ${profile.name}. Source device had a stored Trojan password — re-enter it on this device to complete handoff.'
                  : 'Imported profile: ${profile.name}. Password stays external.';

      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

      if (needsPasswordHandoff) {
        if (!context.mounted) return;
        final handoffPassword = await showTrojanPasswordDialog(
          context,
          title: 'Complete Password Handoff',
          helperText:
              'This imported profile needs a local Trojan password to finish handoff.',
          submitLabel: 'Save & Complete',
        );
        if (!context.mounted) return;
        if (handoffPassword != null && handoffPassword.trim().isNotEmpty) {
          await services.profileSecrets.saveTrojanPassword(
            profileId: profile.id,
            password: handoffPassword,
          );
          services.profileStore.upsertProfile(
            profile.copyWith(hasStoredPassword: true),
          );
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Password handoff completed for ${profile.name}.'),
            ),
          );
        }
      }
    } on FormatException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Import failed: JSON format is invalid for this shell.'),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $error')),
      );
    }
  }
}

class _SelectedProfileCard extends StatefulWidget {
  const _SelectedProfileCard({
    required this.services,
    required this.selected,
    required this.status,
    this.onOpenAdvanced,
    this.onOpenSettings,
  });

  final ClientServiceRegistry services;
  final ClientProfile selected;
  final ClientConnectionStatus status;
  final ValueChanged<ReadinessAction>? onOpenAdvanced;
  final VoidCallback? onOpenSettings;

  @override
  State<_SelectedProfileCard> createState() => _SelectedProfileCardState();
}

class _SelectedProfileCardState extends State<_SelectedProfileCard> {
  late final ReadinessSurfaceController _readinessController;
  String? _lastRefreshFingerprint;

  ClientServiceRegistry get services => widget.services;
  ClientProfile get selected => widget.selected;
  ClientConnectionStatus get status => widget.status;

  bool get _active => status.activeProfileId == selected.id;

  bool get _sessionLockedForProfileEdits =>
      _active &&
      (status.phase == ClientConnectionPhase.connecting ||
          status.phase == ClientConnectionPhase.connected ||
          status.phase == ClientConnectionPhase.disconnecting);

  bool get _hasConnectedElsewhere =>
      !_active && status.phase == ClientConnectionPhase.connected;

  bool get _connectBlockedByReadiness {
    final report = _readinessController.latestReport;
    if (report == null) return false;
    final isConnectAction =
        !(_active && status.phase == ClientConnectionPhase.connected);
    return isConnectAction && report.overallLevel == ReadinessLevel.blocked;
  }

  bool get _canToggleConnection {
    if (!selected.hasStoredPassword) return false;
    if (status.isBusy) return false;
    if (_hasConnectedElsewhere) return false;
    if (_connectBlockedByReadiness) return false;
    return true;
  }

  String get _connectActionLabel {
    if (!selected.hasStoredPassword) return 'Set Password First';
    if (_connectBlockedByReadiness) return 'Connect Blocked';
    if (_active && status.phase == ClientConnectionPhase.connected) {
      return 'Disconnect';
    }
    if (_active && status.phase == ClientConnectionPhase.connecting) {
      return 'Connecting...';
    }
    if (_active && status.phase == ClientConnectionPhase.disconnecting) {
      return 'Disconnecting...';
    }
    if (_hasConnectedElsewhere) {
      return 'Connected Elsewhere';
    }
    return 'Connect';
  }

  String get _statusHint {
    if (!selected.hasStoredPassword) {
      return 'Save the Trojan password before trying this profile.';
    }
    if (_hasConnectedElsewhere) {
      return 'Another profile is already connected. Disconnect it before switching here.';
    }
    if (_active && status.phase == ClientConnectionPhase.connecting) {
      return 'This profile is still establishing a runtime session.';
    }
    if (_active && status.phase == ClientConnectionPhase.disconnecting) {
      return 'This profile is disconnecting now. Wait for the shutdown to finish.';
    }
    if (_connectBlockedByReadiness) {
      return 'Readiness blocked: ${_readinessController.latestReport!.summary}';
    }
    return status.message;
  }

  @override
  void initState() {
    super.initState();
    _readinessController = ReadinessSurfaceController(
      isMounted: () => mounted,
      applyState: setState,
    );
    _lastRefreshFingerprint = _refreshFingerprint();
    _readinessController.initialize(
      refreshKey: _lastRefreshFingerprint!,
      restoreReport: () => services.readiness.readLastKnownReport(
        profileOverride: selected,
      ),
      buildReport: () => services.readiness.buildReport(
        profileOverride: selected,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant _SelectedProfileCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _refreshReadinessIfInputsChanged();
  }

  String _refreshFingerprint() {
    return buildReadinessRefreshFingerprint(
      profile: selected,
      storageSummary: services.profileSecrets.storageSummary,
      runtimeMode: services.controller.runtimeConfig.mode,
      runtimeEndpointHint: services.controller.runtimeConfig.endpointHint,
    );
  }

  void _refreshReadinessIfInputsChanged() {
    final fingerprint = _refreshFingerprint();
    if (_lastRefreshFingerprint == fingerprint) return;
    _lastRefreshFingerprint = fingerprint;
    _readinessController.startCycle(
      restoreReport: () => services.readiness.readLastKnownReport(
        profileOverride: selected,
      ),
      buildReport: () => services.readiness.buildReport(
        profileOverride: selected,
      ),
    );
  }

  void _runRecommendation(BuildContext context, ReadinessRecommendation rec) {
    switch (rec.action) {
      case ReadinessAction.openProfiles:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'You are already in Profiles. Update this profile directly.'),
          ),
        );
        return;
      case ReadinessAction.openTroubleshooting:
        if (widget.onOpenAdvanced != null) {
          widget.onOpenAdvanced!.call(rec.action);
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Troubleshooting page is unavailable in this surface.'),
          ),
        );
        return;
      case ReadinessAction.openSettings:
        if (widget.onOpenSettings != null) {
          widget.onOpenSettings!.call();
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings page is unavailable in this surface.'),
          ),
        );
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _active;
    final posture = describeRuntimePosture(
      runtimeMode: services.controller.runtimeConfig.mode,
      backendKind: services.controller.telemetry.backendKind,
    );

    return SectionCard(
      title: selected.name,
      subtitle: 'Selected profile details and shell-level actions.',
      trailing: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          OutlinedButton(
            onPressed: () => _exportToFile(context),
            child: const Text('Export File'),
          ),
          OutlinedButton(
            onPressed: () => _export(context),
            child: const Text('Export Text'),
          ),
          OutlinedButton(
            onPressed:
                _sessionLockedForProfileEdits ? null : () => _edit(context),
            child: const Text('Edit'),
          ),
          OutlinedButton(
            onPressed: _sessionLockedForProfileEdits
                ? null
                : () => _setTrojanPassword(context),
            child: Text(selected.hasStoredPassword
                ? 'Update Password'
                : 'Set Password'),
          ),
          OutlinedButton(
            onPressed:
                selected.hasStoredPassword && !_sessionLockedForProfileEdits
                    ? () => _rotateTrojanPassword(context)
                    : null,
            child: const Text('Rotate Password'),
          ),
          OutlinedButton(
            onPressed: selected.hasStoredPassword
                ? () => _viewTrojanPassword(context)
                : null,
            child: const Text('View Password'),
          ),
          OutlinedButton(
            onPressed:
                selected.hasStoredPassword && !_sessionLockedForProfileEdits
                    ? () => _clearTrojanPassword(context)
                    : null,
            child: const Text('Clear Password'),
          ),
          OutlinedButton(
            onPressed: _sessionLockedForProfileEdits
                ? null
                : () => _removeProfile(context),
            child: const Text('Remove'),
          ),
          FilledButton(
            onPressed: _canToggleConnection
                ? () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final isDisconnectAction = active &&
                        status.phase == ClientConnectionPhase.connected;
                    if (!isDisconnectAction) {
                      final readinessReport = await services.readiness
                          .buildReport(profileOverride: selected);
                      if (!mounted) return;
                      _readinessController.replaceLatestReport(readinessReport);
                      if (readinessReport.overallLevel ==
                          ReadinessLevel.blocked) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Connect blocked: ${readinessReport.summary}',
                            ),
                          ),
                        );
                        return;
                      }
                    }

                    final result = isDisconnectAction
                        ? await services.controller.disconnect()
                        : await services.controller.connect(selected);
                    if (!context.mounted) return;
                    messenger.showSnackBar(
                      SnackBar(content: Text(result.summary)),
                    );
                  }
                : null,
            child: Text(_connectActionLabel),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _detail('Server', '${selected.serverHost}:${selected.serverPort}'),
            _detail('SNI', selected.sni),
            _detail('Local SOCKS Port', '${selected.localSocksPort}'),
            _detail('TLS Verification',
                selected.verifyTls ? 'Enabled' : 'Disabled'),
            _detail('Runtime Mode', services.controller.runtimeConfig.mode),
            _detail('Runtime Posture', posture.postureLabel),
            _detail('Execution Path', posture.executionPathLabel),
            _detail('Runtime Truth', posture.truthNote),
            _detail('Runtime Endpoint',
                services.controller.runtimeConfig.endpointHint),
            _detail(
              'Trojan Password',
              selected.hasStoredPassword
                  ? services.profileSecrets.isSecureStorageReady
                      ? 'Stored in secure storage'
                      : 'Stored in temporary fallback (${services.profileSecrets.storageSummary})'
                  : 'Not stored',
            ),
            _detail('Secret Storage', services.profileSecrets.storageSummary),
            _detail('Updated', selected.updatedAt.toIso8601String()),
            if (selected.notes.isNotEmpty) _detail('Notes', selected.notes),
            const SizedBox(height: 12),
            FutureBuilder<ReadinessReport>(
              future: _readinessController.future,
              builder: (BuildContext context,
                  AsyncSnapshot<ReadinessReport> snapshot) {
                final report =
                    snapshot.data ?? _readinessController.latestReport;
                return _ProfileReadinessNotice(
                  report: report,
                  showCachedRefreshHint: report?.isCachedSnapshot == true &&
                      snapshot.connectionState != ConnectionState.done,
                  onRecommendation: report?.recommendation == null
                      ? null
                      : () => _runRecommendation(
                            context,
                            report!.recommendation!,
                          ),
                );
              },
            ),
            const SizedBox(height: 12),
            Text('Controller status: $_statusHint'),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final updated = await showProfileEditorDialog(context, initial: selected);
    if (updated == null) return;
    services.profileStore.upsertProfile(updated);
  }

  Future<void> _setTrojanPassword(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final password = await showTrojanPasswordDialog(
      context,
      title: selected.hasStoredPassword
          ? 'Update Trojan Password'
          : 'Set Trojan Password',
      submitLabel: selected.hasStoredPassword ? 'Save Update' : 'Save Password',
    );
    if (password == null || password.trim().isEmpty) return;
    try {
      await services.profileSecrets.saveTrojanPassword(
        profileId: selected.id,
        password: password,
      );
      services.profileStore.upsertProfile(selected.copyWith(
        hasStoredPassword: true,
        updatedAt: DateTime.now(),
      ));
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            services.profileSecrets.isSecureStorageReady
                ? 'Trojan password stored in secure storage.'
                : 'Trojan password stored, but only in temporary fallback storage for this session.',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to store password: $error')),
      );
    }
  }

  Future<void> _rotateTrojanPassword(BuildContext context) async {
    await _setTrojanPassword(context);
  }

  Future<void> _viewTrojanPassword(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final password =
          await services.profileSecrets.readTrojanPassword(selected.id);
      if (!context.mounted) return;
      if (password == null || password.trim().isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
              content: Text('No Trojan password stored for this profile.')),
        );
        return;
      }
      await showTrojanPasswordRevealDialog(
        context,
        profileName: selected.name,
        password: password,
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to read password: $error')),
      );
    }
  }

  Future<void> _clearTrojanPassword(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await _confirmAction(
      context,
      title: 'Clear Trojan Password?',
      body:
          'This removes the stored Trojan password from local secure storage.',
      confirmLabel: 'Clear',
    );
    if (!confirmed) return;

    try {
      await services.profileSecrets.clearTrojanPassword(selected.id);
      services.profileStore.upsertProfile(selected.copyWith(
        hasStoredPassword: false,
        updatedAt: DateTime.now(),
      ));
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Trojan password removed from secure storage.')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to clear password: $error')),
      );
    }
  }

  Future<void> _removeProfile(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await _confirmAction(
      context,
      title: 'Remove Profile?',
      body:
          'This removes profile metadata and clears its stored Trojan password (if present).',
      confirmLabel: 'Remove',
    );
    if (!confirmed) return;

    try {
      if (selected.hasStoredPassword) {
        await services.profileSecrets.clearTrojanPassword(selected.id);
      }
      services.profileStore.removeSelectedProfile();
      messenger.showSnackBar(
        SnackBar(content: Text('Removed profile: ${selected.name}')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to remove profile: $error')),
      );
    }
  }

  Future<void> _export(BuildContext context) async {
    final text = services.profilePortability.exportProfile(selected);
    await showExportTextDialog(
      context,
      title: 'Exported Profile JSON',
      text: text,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Profile JSON exported. Trojan password is not included in this bundle.'),
      ),
    );
  }

  Future<void> _exportToFile(BuildContext context) async {
    final suggestedPath =
        '${Directory.systemTemp.path}${Platform.pathSeparator}${selected.id}-profile.json';
    final outputPath = await showPathInputDialog(
      context,
      title: 'Export Profile To File',
      hintText: '/path/to/exported-profile.json',
      initialValue: suggestedPath,
      confirmLabel: 'Save',
    );
    if (outputPath == null || outputPath.trim().isEmpty) return;

    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = File(outputPath.trim());
      await file.parent.create(recursive: true);
      final text = services.profilePortability.exportProfile(selected);
      await file.writeAsString(text, flush: true);
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Profile exported to ${file.path}. Trojan password is not included in this bundle.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Export file failed: $error')),
      );
    }
  }

  Future<bool> _confirmAction(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Widget _detail(String label, String value) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final useStackedLayout = constraints.maxWidth < 520;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: useStackedLayout
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(value),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(width: 140, child: Text(label)),
                    Expanded(child: Text(value)),
                  ],
                ),
        );
      },
    );
  }
}

class _ProfileReadinessNotice extends StatelessWidget {
  const _ProfileReadinessNotice({
    required this.report,
    this.showCachedRefreshHint = false,
    this.onRecommendation,
  });

  final ReadinessReport? report;
  final bool showCachedRefreshHint;
  final VoidCallback? onRecommendation;

  Color _tone(ReadinessLevel level) {
    return switch (level) {
      ReadinessLevel.ready => Colors.green,
      ReadinessLevel.degraded => Colors.orange,
      ReadinessLevel.blocked => Colors.red,
    };
  }

  IconData _recommendationIcon(ReadinessAction action) {
    return switch (action) {
      ReadinessAction.openProfiles => Icons.storage_outlined,
      ReadinessAction.openTroubleshooting => Icons.build_circle_outlined,
      ReadinessAction.openSettings => Icons.settings_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (report == null) {
      return const SizedBox.shrink();
    }

    final tone = _tone(report!.overallLevel);
    final recommendation = report!.recommendation;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tone.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Readiness: ${report!.overallLevel.label}',
            style: TextStyle(
              color: tone,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(report!.summary),
          const SizedBox(height: 8),
          Text(
            'Readiness source: ${report!.provenanceSummary}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (showCachedRefreshHint) ...<Widget>[
            const SizedBox(height: 8),
            const Text(
              'Showing a cached snapshot while the live readiness refresh runs.',
            ),
          ],
          if (recommendation != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'Recommended next step: ${recommendation.label}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onRecommendation,
              icon: Icon(_recommendationIcon(recommendation.action)),
              label: Text(recommendation.label),
            ),
          ],
        ],
      ),
    );
  }
}
