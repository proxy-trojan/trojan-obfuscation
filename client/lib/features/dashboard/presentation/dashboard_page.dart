import 'package:flutter/material.dart';

import '../../../core/widgets/section_card.dart';
import '../../../platform/services/service_registry.dart';
import '../../controller/domain/client_connection_status.dart';
import '../../profiles/domain/client_profile.dart';
import '../application/connection_lifecycle_view_model.dart';

Widget _kvWidget(String label, String value) {
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
        final lifecycle = ConnectionLifecycleViewModel.fromStatus(
          status: status,
          selectedProfile: profile,
        );
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
            else
              _ConnectionHomeCard(
                lifecycle: lifecycle,
                profile: profile,
                status: status,
                runtimeMode: runtimeConfig.mode,
                controllerBackend: telemetry.backendKind,
                controllerVersion: telemetry.backendVersion,
                updateChannel:
                    services.settingsStore.settings.updateChannel.name,
                storageSummary: services.profileSecrets.storageSummary,
                onOpenProfiles: onOpenProfiles,
                onOpenAdvanced: onOpenAdvanced,
              ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'What to do next',
              subtitle:
                  'The app should guide the user, not make them read the system.',
              child: _NextStepGuide(
                services: services,
                profile: profile,
                status: status,
                lifecycle: lifecycle,
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
                      _kvWidget(
                          'Profile Ready', profile == null ? 'No' : 'Yes'),
                      _kvWidget('Password Ready', _passwordReadyLabel(profile)),
                      _kvWidget('Secret Storage',
                          services.profileSecrets.storageSummary),
                      _kvWidget('App Ready', levelName),
                      _kvWidget('Status Note', summary),
                      _kvWidget('Runtime Path', runtimeConfig.endpointHint),
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

  String _passwordReadyLabel(ClientProfile? profile) {
    if (profile == null) return 'N/A';
    return profile.hasStoredPassword ? 'Yes' : 'No';
  }

  bool _showExperimentGuide(
      ClientProfile? profile, ClientConnectionStatus status) {
    if (profile == null) return true;
    if (!profile.hasStoredPassword) return true;
    return status.phase != ClientConnectionPhase.connected &&
        status.phase != ClientConnectionPhase.disconnecting;
  }
}

class _NextStepGuide extends StatelessWidget {
  const _NextStepGuide({
    required this.services,
    required this.profile,
    required this.status,
    required this.lifecycle,
    required this.onOpenProfiles,
    required this.onOpenAdvanced,
  });

  final ClientServiceRegistry services;
  final ClientProfile? profile;
  final ClientConnectionStatus status;
  final ConnectionLifecycleViewModel lifecycle;
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
              onPressed: () => _runAction(context, model.primaryAction),
              child: Text(model.primaryLabel),
            ),
            if (model.secondaryLabel != null)
              OutlinedButton(
                onPressed: () => _runAction(context, model.secondaryAction),
                child: Text(model.secondaryLabel!),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _runAction(BuildContext context, _GuideAction? action) async {
    if (action == null) return;

    switch (action) {
      case _GuideAction.openProfiles:
        onOpenProfiles?.call();
        return;
      case _GuideAction.openAdvanced:
        onOpenAdvanced?.call();
        return;
      case _GuideAction.connectNow:
      case _GuideAction.retryNow:
        final currentProfile = profile;
        if (currentProfile == null) return;
        final result = await services.controller.connect(currentProfile);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.summary)),
        );
        return;
      case _GuideAction.disconnectNow:
        final result = await services.controller.disconnect();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.summary)),
        );
        return;
    }
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
      return _GuideModel(
        title: lifecycle.headline,
        body: lifecycle.detail,
        primaryLabel: lifecycle.showRetry ? 'Retry now' : 'Open Profiles',
        primaryAction: lifecycle.showRetry
            ? _GuideAction.retryNow
            : _GuideAction.openProfiles,
        secondaryLabel:
            lifecycle.showOpenTroubleshooting ? 'Open Troubleshooting' : null,
        secondaryAction: lifecycle.showOpenTroubleshooting
            ? _GuideAction.openAdvanced
            : null,
      );
    }
    if (status.phase == ClientConnectionPhase.connected) {
      return const _GuideModel(
        title: 'Connection is active',
        body:
            'You are already connected. Disconnect here if you want to end the current session, or open Profiles to switch context.',
        primaryLabel: 'Disconnect now',
        primaryAction: _GuideAction.disconnectNow,
        secondaryLabel: 'Open Profiles',
        secondaryAction: _GuideAction.openProfiles,
      );
    }
    if (status.phase == ClientConnectionPhase.disconnecting) {
      return _GuideModel(
        title: lifecycle.headline,
        body: lifecycle.detail,
        primaryLabel: 'Open Troubleshooting',
        primaryAction: _GuideAction.openAdvanced,
        secondaryLabel: 'Open Profiles',
        secondaryAction: _GuideAction.openProfiles,
      );
    }
    if (status.phase == ClientConnectionPhase.connecting) {
      return _GuideModel(
        title: lifecycle.headline,
        body: lifecycle.detail,
        primaryLabel: 'Open Troubleshooting',
        primaryAction: _GuideAction.openAdvanced,
        secondaryLabel: 'Open Profiles',
        secondaryAction: _GuideAction.openProfiles,
      );
    }
    return const _GuideModel(
      title: 'You are ready for a quick test',
      body:
          'Use one clear Connect action here, or open Profiles if you want to review the selected profile first.',
      primaryLabel: 'Connect now',
      primaryAction: _GuideAction.connectNow,
      secondaryLabel: 'Open Profiles',
      secondaryAction: _GuideAction.openProfiles,
    );
  }
}

enum _GuideAction {
  openProfiles,
  openAdvanced,
  connectNow,
  retryNow,
  disconnectNow,
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

class _ConnectionHomeCard extends StatelessWidget {
  const _ConnectionHomeCard({
    required this.lifecycle,
    required this.profile,
    required this.status,
    required this.runtimeMode,
    required this.controllerBackend,
    required this.controllerVersion,
    required this.updateChannel,
    required this.storageSummary,
    required this.onOpenProfiles,
    required this.onOpenAdvanced,
  });

  final ConnectionLifecycleViewModel lifecycle;
  final ClientProfile profile;
  final ClientConnectionStatus status;
  final String runtimeMode;
  final String controllerBackend;
  final String controllerVersion;
  final String updateChannel;
  final String storageSummary;
  final VoidCallback? onOpenProfiles;
  final VoidCallback? onOpenAdvanced;

  Color get _accentColor => switch (lifecycle.stage) {
        ConnectionLifecycleStage.idle => Colors.blue,
        ConnectionLifecycleStage.connecting => Colors.orange,
        ConnectionLifecycleStage.connected => Colors.green,
        ConnectionLifecycleStage.disconnecting => Colors.orange,
        ConnectionLifecycleStage.error => Colors.red,
      };

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Connection Home',
      subtitle:
          'The primary path should be obvious: profile → password → connect.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _accentColor.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            lifecycle.headline,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(lifecycle.detail),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _LifecyclePill(
                      label: lifecycle.label,
                      color: _accentColor,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  children: <Widget>[
                    _kvWidget('Lifecycle', lifecycle.label),
                    _kvWidget('Selected Profile', profile.name),
                    _kvWidget('Active Profile',
                        lifecycle.activeProfileName ?? 'None'),
                    _kvWidget('Status Note', lifecycle.statusSummary),
                    _kvWidget('Secret Storage', storageSummary),
                    _kvWidget('Runtime Mode', runtimeMode),
                    _kvWidget('Controller Backend', controllerBackend),
                    _kvWidget('Backend Version', controllerVersion),
                    _kvWidget('Update Channel', updateChannel),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    if (lifecycle.showRetry)
                      FilledButton.icon(
                        onPressed: lifecycle.canConnect ? onOpenProfiles : null,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry from Profiles'),
                      ),
                    if (lifecycle.showOpenProfiles)
                      OutlinedButton.icon(
                        onPressed: onOpenProfiles,
                        icon: const Icon(Icons.list_alt),
                        label: const Text('Open Profiles'),
                      ),
                    if (lifecycle.showOpenTroubleshooting)
                      OutlinedButton.icon(
                        onPressed: onOpenAdvanced,
                        icon: const Icon(Icons.build_circle_outlined),
                        label: const Text('Open Troubleshooting'),
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

class _LifecyclePill extends StatelessWidget {
  const _LifecyclePill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StateCalloutCard extends StatelessWidget {
  const _StateCalloutCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.primaryLabel,
    this.onPrimary,
  });

  final IconData icon;
  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback? onPrimary;

  @override
  Widget build(BuildContext context) {
    const color = Colors.blue;

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
                FilledButton(
                  onPressed: onPrimary,
                  child: Text(primaryLabel),
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
            _kvWidget('Running', session.isRunning ? 'Yes' : 'No'),
            _kvWidget('PID', session.pid?.toString() ?? 'N/A'),
            _kvWidget('Config Path', session.activeConfigPath ?? 'N/A'),
            _kvWidget(
                'Last Exit Code', session.lastExitCode?.toString() ?? 'N/A'),
            _kvWidget('Last Error', session.lastError ?? 'None'),
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
