import 'package:flutter/material.dart';

import '../../../core/widgets/section_card.dart';
import '../../../platform/services/service_registry.dart';
import '../../controller/domain/client_connection_status.dart';
import '../../profiles/domain/client_profile.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.services,
    this.onOpenProfiles,
    this.onOpenAdvanced,
  });

  final ClientServiceRegistry services;
  final VoidCallback? onOpenProfiles;
  final VoidCallback? onOpenAdvanced;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        services.profileStore,
        services.controller,
        services.settingsStore,
      ]),
      builder: (BuildContext context, _) {
        final profile = services.profileStore.selectedProfile;
        final status = services.controller.status;
        final runtimeConfig = services.controller.runtimeConfig;
        final telemetry = services.controller.telemetry;

        return ListView(
          children: <Widget>[
            if (profile == null)
              _StateCalloutCard(
                icon: Icons.playlist_add,
                title: 'Add one profile to get started',
                body:
                    'The first useful step is simple: create or import one profile, then save its password and try one connection.',
                primaryLabel: 'Open Profiles',
                onPrimary: onOpenProfiles,
              )
            else if (!profile.hasStoredPassword)
              _StateCalloutCard(
                icon: Icons.password,
                title: 'Save the password before testing',
                body:
                    'This profile is almost ready. Save the password first, then try one connection attempt.',
                primaryLabel: 'Open Profiles',
                onPrimary: onOpenProfiles,
              )
            else if (status.phase == ClientConnectionPhase.error)
              _StateCalloutCard(
                icon: Icons.error_outline,
                title: 'The last connection did not work',
                body:
                    'Open Troubleshooting if you want a clear report. Go back to Profiles if you want to try again.',
                primaryLabel: 'Open Troubleshooting',
                onPrimary: onOpenAdvanced,
                secondaryLabel: 'Open Profiles',
                onSecondary: onOpenProfiles,
                isWarning: true,
              )
            else
              SectionCard(
                title: 'Connection Home',
                subtitle:
                    'The primary path should be obvious: profile → password → connect.',
                child: Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  children: <Widget>[
                    _kv('Connection Status', _statusLabel(status)),
                    _kv('Selected Profile', profile.name),
                    _kv('Password Ready', _passwordReadyLabel(profile)),
                    _kv('Secret Storage',
                        services.profileSecrets.storageSummary),
                    _kv('Runtime Mode', runtimeConfig.mode),
                    _kv('Controller Backend', telemetry.backendKind),
                    _kv('Backend Version', telemetry.backendVersion),
                    _kv('Update Channel',
                        services.settingsStore.settings.updateChannel.name),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'What to do next',
              subtitle:
                  'The app should guide the user, not make them read the system.',
              child: _NextStepGuide(
                profile: profile,
                status: status,
                onOpenProfiles: onOpenProfiles,
                onOpenAdvanced: onOpenAdvanced,
              ),
            ),
            const SizedBox(height: 16),
            if (_showExperimentGuide(profile, status)) ...<Widget>[
              const SectionCard(
                title: 'Experiment quick start',
                subtitle:
                    'Keep the workflow short and obvious when you are testing.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('1. Go to Profiles and create or import one profile.'),
                    SizedBox(height: 8),
                    Text('2. Save the Trojan password for that profile.'),
                    SizedBox(height: 8),
                    Text(
                        '3. Try one connect attempt and watch the status only.'),
                    SizedBox(height: 8),
                    Text(
                        '4. If it fails, open Advanced → Troubleshooting and export the bundle.'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            SectionCard(
              title: 'Before you connect',
              subtitle: 'Only the facts the user needs before trying one test.',
              child: FutureBuilder(
                future: services.controller.checkHealth(),
                builder: (BuildContext context, snapshot) {
                  final health = snapshot.data;
                  final levelName =
                      health == null ? 'Checking…' : health.level.name;
                  final summary =
                      health == null ? 'Probing local runtime' : health.summary;

                  return Wrap(
                    spacing: 24,
                    runSpacing: 12,
                    children: <Widget>[
                      _kv('Profile Ready', profile == null ? 'No' : 'Yes'),
                      _kv('Password Ready', _passwordReadyLabel(profile)),
                      _kv('Secret Storage',
                          services.profileSecrets.storageSummary),
                      _kv('App Ready', levelName),
                      _kv('Status Note', summary),
                      _kv('Runtime Path', runtimeConfig.endpointHint),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            ExpansionTile(
              title: const Text('Advanced runtime session'),
              subtitle: const Text('PID / logs / exit details for debugging.'),
              children: <Widget>[
                SectionCard(
                  title: 'Runtime Session',
                  child: _RuntimeSessionSummary(services: services),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  String _statusLabel(ClientConnectionStatus status) {
    return switch (status.phase) {
      ClientConnectionPhase.disconnected => 'Disconnected',
      ClientConnectionPhase.connecting => 'Connecting',
      ClientConnectionPhase.connected => 'Connected',
      ClientConnectionPhase.error => 'Needs attention',
    };
  }

  String _passwordReadyLabel(ClientProfile? profile) {
    if (profile == null) return 'N/A';
    return profile.hasStoredPassword ? 'Yes' : 'No';
  }

  bool _showExperimentGuide(
      ClientProfile? profile, ClientConnectionStatus status) {
    if (profile == null) return true;
    if (!profile.hasStoredPassword) return true;
    return status.phase != ClientConnectionPhase.connected;
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

class _NextStepGuide extends StatelessWidget {
  const _NextStepGuide({
    required this.profile,
    required this.status,
    required this.onOpenProfiles,
    required this.onOpenAdvanced,
  });

  final ClientProfile? profile;
  final ClientConnectionStatus status;
  final VoidCallback? onOpenProfiles;
  final VoidCallback? onOpenAdvanced;

  @override
  Widget build(BuildContext context) {
    final model = _model();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(model.title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(model.body),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            FilledButton(
              onPressed: model.primaryAction == _GuideAction.openProfiles
                  ? onOpenProfiles
                  : model.primaryAction == _GuideAction.openAdvanced
                      ? onOpenAdvanced
                      : null,
              child: Text(model.primaryLabel),
            ),
            if (model.secondaryLabel != null)
              OutlinedButton(
                onPressed: model.secondaryAction == _GuideAction.openProfiles
                    ? onOpenProfiles
                    : model.secondaryAction == _GuideAction.openAdvanced
                        ? onOpenAdvanced
                        : null,
                child: Text(model.secondaryLabel!),
              ),
          ],
        ),
      ],
    );
  }

  _GuideModel _model() {
    if (profile == null) {
      return const _GuideModel(
        title: 'Start by adding one profile',
        body:
            'Create or import a profile first. Once that exists, the rest of the flow becomes much simpler.',
        primaryLabel: 'Open Profiles',
        primaryAction: _GuideAction.openProfiles,
      );
    }
    if (!profile!.hasStoredPassword) {
      return const _GuideModel(
        title: 'Save the password before testing',
        body:
            'The selected profile still needs its Trojan password. Save it first, then try one connection attempt.',
        primaryLabel: 'Open Profiles',
        primaryAction: _GuideAction.openProfiles,
      );
    }
    if (status.phase == ClientConnectionPhase.error) {
      return const _GuideModel(
        title: 'The last test needs troubleshooting',
        body:
            'Your previous connection attempt failed. Open Troubleshooting if you need runtime details or a support bundle.',
        primaryLabel: 'Open Troubleshooting',
        primaryAction: _GuideAction.openAdvanced,
        secondaryLabel: 'Open Profiles',
        secondaryAction: _GuideAction.openProfiles,
      );
    }
    if (status.phase == ClientConnectionPhase.connected) {
      return const _GuideModel(
        title: 'Connection is active',
        body:
            'You are already connected. If you want to switch profiles or disconnect, go back to Profiles.',
        primaryLabel: 'Open Profiles',
        primaryAction: _GuideAction.openProfiles,
      );
    }
    if (status.phase == ClientConnectionPhase.connecting) {
      return const _GuideModel(
        title: 'Connection attempt is running',
        body:
            'Wait for the current attempt to finish. If it stalls, open Troubleshooting for deeper details.',
        primaryLabel: 'Open Troubleshooting',
        primaryAction: _GuideAction.openAdvanced,
        secondaryLabel: 'Open Profiles',
        secondaryAction: _GuideAction.openProfiles,
      );
    }
    return const _GuideModel(
      title: 'You are ready for a quick test',
      body:
          'Open Profiles and use the selected profile to try one connect attempt.',
      primaryLabel: 'Open Profiles',
      primaryAction: _GuideAction.openProfiles,
      secondaryLabel: 'Open Troubleshooting',
      secondaryAction: _GuideAction.openAdvanced,
    );
  }
}

enum _GuideAction {
  openProfiles,
  openAdvanced,
}

class _GuideModel {
  const _GuideModel({
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.primaryAction,
    this.secondaryLabel,
    this.secondaryAction,
  });

  final String title;
  final String body;
  final String primaryLabel;
  final _GuideAction primaryAction;
  final String? secondaryLabel;
  final _GuideAction? secondaryAction;
}

class _StateCalloutCard extends StatelessWidget {
  const _StateCalloutCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.isWarning = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final color = isWarning ? Colors.orange : Colors.blue;

    return SectionCard(
      title: title,
      subtitle: 'User-facing guidance should be obvious and short.',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(body),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    FilledButton(
                      onPressed: onPrimary,
                      child: Text(primaryLabel),
                    ),
                    if (secondaryLabel != null)
                      OutlinedButton(
                        onPressed: onSecondary,
                        child: Text(secondaryLabel!),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RuntimeSessionSummary extends StatelessWidget {
  const _RuntimeSessionSummary({required this.services});

  final ClientServiceRegistry services;

  @override
  Widget build(BuildContext context) {
    final session = services.controller.session;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 24,
          runSpacing: 12,
          children: <Widget>[
            _kv('Running', session.isRunning ? 'Yes' : 'No'),
            _kv('PID', session.pid?.toString() ?? 'N/A'),
            _kv('Config Path', session.activeConfigPath ?? 'N/A'),
            _kv('Last Exit Code', session.lastExitCode?.toString() ?? 'N/A'),
            _kv('Last Error', session.lastError ?? 'None'),
          ],
        ),
        const SizedBox(height: 12),
        if (session.stdoutTail.isNotEmpty)
          _logTail('stdout tail', session.stdoutTail),
        if (session.stderrTail.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          _logTail('stderr tail', session.stderrTail),
        ],
      ],
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

  Widget _logTail(String label, List<String> lines) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(lines.join('\n')),
        ),
      ],
    );
  }
}
