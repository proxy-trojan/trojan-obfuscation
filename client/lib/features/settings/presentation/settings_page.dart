import 'package:flutter/material.dart';

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
        final packagingWorkflow = services.packagingStore.state;

        return SectionCard(
          title: 'Settings',
          subtitle: 'Product-layer settings, not runtime internals.',
          child: Column(
            children: <Widget>[
              DropdownButtonFormField<ThemeMode>(
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
                  if (value != null) services.settingsStore.setThemeMode(value);
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<UpdateChannel>(
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
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
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
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Update boundary: contract ${packagingWorkflow.releaseMetadataContractVersion} · ${packagingWorkflow.rolloutPolicySummary}',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.launchOnLogin,
                onChanged: services.settingsStore.setLaunchOnLogin,
                title: const Text('Open on login'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<DesktopCloseBehavior>(
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
              Row(
                children: <Widget>[
                  const Expanded(child: Text('Diagnostics retention (days)')),
                  DropdownButton<int>(
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
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Desktop lifecycle policy',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Close: ${lifecyclePolicy.closeSemanticsSummary(trayReady: lifecycleStatus.trayReady)}',
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                    'Minimize: ${lifecyclePolicy.minimizeSemanticsSummary()}'),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Quit: ${lifecyclePolicy.quitSemanticsSummary()}'),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Lifecycle status: ${lifecycleStatus.summary}'),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Update channel skeleton',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                    'Current channel: ${packagingWorkflow.selectedChannel.name}'),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Last check: ${packagingWorkflow.lastUpdateCheckAt?.toIso8601String() ?? 'never'}',
                ),
              ),
              const SizedBox(height: 4),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Self-update is not wired in v1.3.0; current actions only exercise the product boundary and metadata contract.',
                ),
              ),
            ],
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
