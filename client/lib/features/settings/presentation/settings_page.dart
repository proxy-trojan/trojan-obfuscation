import 'package:flutter/material.dart';

import '../../../core/widgets/section_card.dart';
import '../../../platform/services/service_registry.dart';
import '../domain/app_settings.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.services});

  final ClientServiceRegistry services;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: services.settingsStore,
      builder: (BuildContext context, _) {
        final settings = services.settingsStore.settings;
        return SectionCard(
          title: 'Settings',
          subtitle: 'Product-layer settings, not runtime internals.',
          child: Column(
            children: <Widget>[
              DropdownButtonFormField<ThemeMode>(
                value: settings.themeMode,
                decoration: const InputDecoration(labelText: 'Theme mode'),
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
                value: settings.updateChannel,
                decoration: const InputDecoration(labelText: 'Update channel'),
                items: UpdateChannel.values
                    .map(
                      (channel) => DropdownMenuItem<UpdateChannel>(
                        value: channel,
                        child: Text(channel.name),
                      ),
                    )
                    .toList(),
                onChanged: (UpdateChannel? value) {
                  if (value != null) services.settingsStore.setUpdateChannel(value);
                },
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.launchOnLogin,
                onChanged: services.settingsStore.setLaunchOnLogin,
                title: const Text('Launch on login'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.collectDiagnostics,
                onChanged: services.settingsStore.setCollectDiagnostics,
                title: const Text('Collect diagnostics'),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  const Expanded(child: Text('Diagnostics retention (days)')),
                  DropdownButton<int>(
                    value: settings.diagnosticsRetentionDays,
                    items: const <int>[3, 7, 14, 30]
                        .map((int value) => DropdownMenuItem<int>(
                              value: value,
                              child: Text('$value'),
                            ))
                        .toList(),
                    onChanged: (int? value) {
                      if (value != null) {
                        services.settingsStore.setDiagnosticsRetentionDays(value);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
