import 'package:flutter/material.dart';

import '../../../core/widgets/section_card.dart';
import '../../../platform/services/service_registry.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.services});

  final ClientServiceRegistry services;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        services.controller,
        services.profileStore,
        services.settingsStore,
      ]),
      builder: (BuildContext context, _) {
        final status = services.controller.status;
        final profile = services.profileStore.selectedProfile;
        final settings = services.settingsStore.settings;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SectionCard(
              title: 'Current Session',
              subtitle: 'High-level client state and active profile snapshot.',
              child: Wrap(
                spacing: 24,
                runSpacing: 12,
                children: <Widget>[
                  _kv('Connection', status.phase.name),
                  _kv('Status', status.message),
                  _kv('Active Profile', profile?.name ?? 'None selected'),
                  _kv('Server',
                      profile == null ? 'N/A' : '${profile.serverHost}:${profile.serverPort}'),
                  _kv('SNI', profile?.sni ?? 'N/A'),
                  _kv('Updated', status.updatedAt.toIso8601String()),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: SectionCard(
                    title: 'Product Layer',
                    subtitle: 'What the shell already knows how to do.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const <Widget>[
                        _ChecklistItem('Profile create/edit/import/export'),
                        _ChecklistItem('Settings state model'),
                        _ChecklistItem('Fake controller boundary'),
                        _ChecklistItem('Diagnostics preview generation'),
                        _ChecklistItem('Desktop-first navigation shell'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SectionCard(
                    title: 'Platform Snapshot',
                    subtitle: 'Current app-level service assumptions.',
                    child: Wrap(
                      spacing: 24,
                      runSpacing: 12,
                      children: <Widget>[
                        _kv('Secure Storage', services.secureStorage.backendName),
                        _kv('Update Channel', settings.updateChannel.name),
                        _kv('Theme Mode', settings.themeMode.name),
                        _kv('Launch On Login', settings.launchOnLogin ? 'Enabled' : 'Disabled'),
                        _kv('Diagnostics', settings.collectDiagnostics ? 'Enabled' : 'Disabled'),
                        _kv('Retention', '${settings.diagnosticsRetentionDays} days'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Next Product Step',
              subtitle: 'Immediate development priorities for the client line.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const <Widget>[
                  Text('1. Add persistent settings/profile storage adapters.'),
                  SizedBox(height: 8),
                  Text('2. Add dashboard event log / controller event timeline.'),
                  SizedBox(height: 8),
                  Text('3. Add diagnostics save-to-file abstraction.'),
                  SizedBox(height: 8),
                  Text('4. Validate with flutter analyze/run in a Flutter-enabled environment.'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _kv(String label, String value) {
    return SizedBox(
      width: 220,
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

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          const Icon(Icons.check_circle, color: Colors.green, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
