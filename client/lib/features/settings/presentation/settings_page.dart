import 'package:flutter/material.dart';

import '../../../core/utils/format_timestamp.dart';
import '../../../core/widgets/section_card.dart';
import '../../../platform/services/desktop_lifecycle_models.dart';
import '../../../platform/services/service_registry.dart';
import '../domain/app_settings.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.services});

  final ClientServiceRegistry services;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        services.settingsStore,
        services.desktopLifecycle,
        services.packagingStore,
      ]),
      builder: (BuildContext context, _) {
        final settings = services.settingsStore.settings;
        final lifecyclePolicy = services.desktopLifecycle.policy;
        final lifecycleStatus = services.desktopLifecycle.status;
        final quickActions = services.desktopLifecycle.quickActions;
        final packagingWorkflow = services.packagingStore.state;

        return SingleChildScrollView(
          child: SectionCard(
            title: 'Settings',
            subtitle: 'Product-layer settings, not runtime internals.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DropdownButtonFormField<ThemeMode>(
                  key:
                      ValueKey<String>('theme-mode-${settings.themeMode.name}'),
                  initialValue: settings.themeMode,
                  decoration: const InputDecoration(labelText: 'Appearance'),
                  items: ThemeMode.values
                      .map(
                        (mode) => DropdownMenuItem<ThemeMode>(
                          value: mode,
                          child: Text(mode.name),
                        ),
                      )
                      .toList(),
                  onChanged: (ThemeMode? value) {
                    if (value != null) {
                      services.settingsStore.setThemeMode(value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<UpdateChannel>(
                  key: ValueKey<String>(
                    'update-channel-${settings.updateChannel.name}',
                  ),
                  initialValue: settings.updateChannel,
                  decoration: const InputDecoration(labelText: 'Update Track'),
                  items: UpdateChannel.values
                      .map(
                        (channel) => DropdownMenuItem<UpdateChannel>(
                          value: channel,
                          child: Text(channel.name),
                        ),
                      )
                      .toList(),
                  onChanged: (UpdateChannel? value) {
                    if (value != null) {
                      services.settingsStore.setUpdateChannel(value);
                      services.packagingStore.syncUpdatePreferences(
                        channel: value,
                        autoCheckForUpdates:
                            services.settingsStore.settings.autoCheckForUpdates,
                      );
                    }
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: settings.autoCheckForUpdates,
                  onChanged: (bool value) {
                    services.settingsStore.setAutoCheckForUpdates(value);
                    services.packagingStore.syncUpdatePreferences(
                      channel: services.settingsStore.settings.updateChannel,
                      autoCheckForUpdates: value,
                    );
                  },
                  title: const Text('Check for updates automatically'),
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    FilledButton.tonal(
                      onPressed: settings.autoCheckForUpdates
                          ? () => services.packagingStore.runStubUpdateCheck()
                          : null,
                      child: const Text('Check for updates now'),
                    ),
                    Text('Status: ${packagingWorkflow.updateCheckStatusLabel}'),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Update boundary: contract ${packagingWorkflow.releaseMetadataContractVersion} · ${packagingWorkflow.rolloutPolicySummary}',
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: settings.launchOnLogin,
                  onChanged: services.settingsStore.setLaunchOnLogin,
                  title: const Text('Open on login'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<DesktopCloseBehavior>(
                  key: ValueKey<String>(
                    'close-behavior-${settings.desktopCloseBehavior.name}',
                  ),
                  initialValue: settings.desktopCloseBehavior,
                  decoration:
                      const InputDecoration(labelText: 'Window close behavior'),
                  items: DesktopCloseBehavior.values
                      .map(
                        (behavior) => DropdownMenuItem<DesktopCloseBehavior>(
                          value: behavior,
                          child: Text(_closeBehaviorLabel(behavior)),
                        ),
                      )
                      .toList(),
                  onChanged: (DesktopCloseBehavior? value) {
                    if (value != null) {
                      services.settingsStore.setDesktopCloseBehavior(value);
                    }
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: settings.collectDiagnostics,
                  onChanged: services.settingsStore.setCollectDiagnostics,
                  title: const Text('Collect troubleshooting data'),
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final useStackedLayout = constraints.maxWidth < 520;
                    final dropdown = DropdownButton<int>(
                      value: settings.diagnosticsRetentionDays,
                      items: const <int>[3, 7, 14, 30]
                          .map(
                            (int value) => DropdownMenuItem<int>(
                              value: value,
                              child: Text('$value'),
                            ),
                          )
                          .toList(),
                      onChanged: (int? value) {
                        if (value != null) {
                          services.settingsStore
                              .setDiagnosticsRetentionDays(value);
                        }
                      },
                    );

                    if (useStackedLayout) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'Diagnostics retention (days)',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          dropdown,
                        ],
                      );
                    }

                    return Row(
                      children: <Widget>[
                        const Expanded(
                          child: Text('Diagnostics retention (days)'),
                        ),
                        dropdown,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                Text(
                  'Desktop lifecycle policy',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Close: ${lifecyclePolicy.closeSemanticsSummary(trayReady: lifecycleStatus.trayReady)}',
                ),
                const SizedBox(height: 4),
                Text(
                  'Minimize: ${lifecyclePolicy.minimizeSemanticsSummary()}',
                ),
                const SizedBox(height: 4),
                Text('Quit: ${lifecyclePolicy.quitSemanticsSummary()}'),
                const SizedBox(height: 8),
                Text('Lifecycle status: ${lifecycleStatus.summary}'),
                const SizedBox(height: 4),
                Text(
                  'Tray integration: ${lifecycleStatus.trayReady ? 'ready' : 'unavailable'}',
                ),
                const SizedBox(height: 4),
                Text(
                  'Close interception: ${lifecycleStatus.closeInterceptEnabled ? 'enabled' : 'disabled'}',
                ),
                const SizedBox(height: 4),
                Text(
                  'Duplicate launch: ${lifecyclePolicy.duplicateLaunchSummary(singleInstancePrimary: lifecycleStatus.singleInstancePrimary)}',
                ),
                const SizedBox(height: 4),
                Text(
                  'Tray policy: ${lifecyclePolicy.trayPolicySummary()}',
                ),
                const SizedBox(height: 4),
                Text(
                  'Quick actions profile: ${quickActions.profileSummary()}',
                ),
                const SizedBox(height: 4),
                Text(
                  'Quick actions readiness: ${quickActions.readinessSummary(trayReady: lifecycleStatus.trayReady)}',
                ),
                const SizedBox(height: 4),
                Text(
                  'External activation: ${lifecycleStatus.externalActivationSummary()}',
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                Text(
                  'Update channel skeleton',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                    'Current channel: ${packagingWorkflow.selectedChannel.name}'),
                const SizedBox(height: 4),
                Text(
                  'Last check: ${formatTimestamp(packagingWorkflow.lastUpdateCheckAt)}',
                ),
                const SizedBox(height: 4),
                const Text(
                  'Self-update is not wired in v1.3.0; current actions only exercise the product boundary and metadata contract.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _closeBehaviorLabel(DesktopCloseBehavior behavior) {
    switch (behavior) {
      case DesktopCloseBehavior.hideToTray:
        return 'Hide to tray';
      case DesktopCloseBehavior.minimizeWindow:
        return 'Minimize window';
      case DesktopCloseBehavior.quitApplication:
        return 'Quit application';
    }
  }
}
