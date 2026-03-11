import 'package:flutter/material.dart';

import '../../../core/widgets/section_card.dart';
import '../../../platform/services/service_registry.dart';
import '../../controller/domain/client_connection_status.dart';
import '../domain/client_profile.dart';
import 'import_export_dialog.dart';
import 'profile_editor_dialog.dart';

class ProfilesPage extends StatelessWidget {
  const ProfilesPage({super.key, required this.services});

  final ClientServiceRegistry services;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[services.profileStore, services.controller]),
      builder: (BuildContext context, _) {
        final profiles = services.profileStore.profiles;
        final selected = services.profileStore.selectedProfile;
        final status = services.controller.status;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              flex: 2,
              child: SectionCard(
                title: 'Profiles',
                subtitle: 'Desktop-first profile management shell.',
                trailing: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: () => _importProfile(context),
                      icon: const Icon(Icons.file_upload),
                      label: const Text('Import'),
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
                                  services.profileStore.selectedProfileId == profile.id
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                ),
                                title: Text(profile.name),
                                subtitle: Text('${profile.serverHost}:${profile.serverPort}'),
                                trailing: status.activeProfileId == profile.id &&
                                        status.phase == ClientConnectionPhase.connected
                                    ? const Icon(Icons.link, color: Colors.green)
                                    : null,
                                onTap: () => services.profileStore.selectProfile(profile.id),
                              ),
                            )
                            .toList(),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: selected == null
                  ? const SectionCard(
                      title: 'Profile Details',
                      child: Text('Select or create a profile to inspect it.'),
                    )
                  : _SelectedProfileCard(
                      services: services,
                      selected: selected,
                      status: status,
                    ),
            ),
          ],
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
    final messenger = ScaffoldMessenger.of(context);
    try {
      final profile = services.profilePortability.importProfile(text);
      services.profileStore.upsertProfile(profile);
      messenger.showSnackBar(SnackBar(content: Text('Imported profile: ${profile.name}')));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Import failed: JSON format is invalid for this shell.')),
      );
    }
  }
}

class _SelectedProfileCard extends StatelessWidget {
  const _SelectedProfileCard({
    required this.services,
    required this.selected,
    required this.status,
  });

  final ClientServiceRegistry services;
  final ClientProfile selected;
  final ClientConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final active = status.activeProfileId == selected.id;

    return SectionCard(
      title: selected.name,
      subtitle: 'Selected profile details and shell-level actions.',
      trailing: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          OutlinedButton(
            onPressed: () => _export(context),
            child: const Text('Export'),
          ),
          OutlinedButton(
            onPressed: () => _edit(context),
            child: const Text('Edit'),
          ),
          OutlinedButton(
            onPressed: services.profileStore.removeSelectedProfile,
            child: const Text('Remove'),
          ),
          FilledButton(
            onPressed: status.isBusy
                ? null
                : () {
                    if (active && status.phase == ClientConnectionPhase.connected) {
                      services.controller.disconnect();
                    } else {
                      services.controller.connect(selected);
                    }
                  },
            child: Text(
              active && status.phase == ClientConnectionPhase.connected ? 'Disconnect' : 'Connect',
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _detail('Server', '${selected.serverHost}:${selected.serverPort}'),
          _detail('SNI', selected.sni),
          _detail('Local SOCKS Port', '${selected.localSocksPort}'),
          _detail('TLS Verification', selected.verifyTls ? 'Enabled' : 'Disabled'),
          _detail('Updated', selected.updatedAt.toIso8601String()),
          if (selected.notes.isNotEmpty) _detail('Notes', selected.notes),
          const SizedBox(height: 12),
          Text('Controller status: ${status.message}'),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final updated = await showProfileEditorDialog(context, initial: selected);
    if (updated == null) return;
    services.profileStore.upsertProfile(updated);
  }

  Future<void> _export(BuildContext context) async {
    final text = services.profilePortability.exportProfile(selected);
    await showExportTextDialog(context, title: 'Exported Profile JSON', text: text);
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(width: 140, child: Text(label)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
