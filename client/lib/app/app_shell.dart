import 'dart:async';

import 'package:flutter/material.dart';

import '../features/advanced/presentation/advanced_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/profiles/presentation/profiles_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../platform/services/service_registry.dart';

class TrojanClientAppShell extends StatefulWidget {
  const TrojanClientAppShell({super.key, required this.services});

  final ClientServiceRegistry services;

  @override
  State<TrojanClientAppShell> createState() => _TrojanClientAppShellState();
}

class _TrojanClientAppShellState extends State<TrojanClientAppShell> {
  int _selectedIndex = 0;
  DateTime? _lastHandledExternalActivationAt;

  @override
  void initState() {
    super.initState();
    widget.services.desktopLifecycle.addListener(_handleDesktopLifecycleChanged);
    unawaited(widget.services.desktopLifecycle.initialize());
  }

  @override
  void dispose() {
    widget.services.desktopLifecycle
        .removeListener(_handleDesktopLifecycleChanged);
    unawaited(widget.services.desktopLifecycle.disposeService());
    super.dispose();
  }

  void _handleDesktopLifecycleChanged() {
    final status = widget.services.desktopLifecycle.status;
    if (!status.isRecentExternalActivation()) {
      return;
    }

    final activatedAt = status.lastExternalActivationAt;
    if (activatedAt == null || activatedAt == _lastHandledExternalActivationAt) {
      return;
    }

    _lastHandledExternalActivationAt = activatedAt;
    if (_selectedIndex != 0 && mounted) {
      setState(() => _selectedIndex = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DashboardPage(
        services: widget.services,
        onOpenProfiles: () => setState(() => _selectedIndex = 1),
        onOpenAdvanced: () => setState(() => _selectedIndex = 3),
        onOpenSettings: () => setState(() => _selectedIndex = 2),
      ),
      ProfilesPage(services: widget.services),
      SettingsPage(services: widget.services),
      AdvancedPage(services: widget.services),
    ];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Trojan Pro Client',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                'Desktop-first connection client. Keep main tasks simple; keep advanced tools out of the way.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Row(
                  children: <Widget>[
                    NavigationRail(
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: (int index) {
                        setState(() => _selectedIndex = index);
                      },
                      labelType: NavigationRailLabelType.all,
                      destinations: const <NavigationRailDestination>[
                        NavigationRailDestination(
                          icon: Icon(Icons.home_outlined),
                          selectedIcon: Icon(Icons.home),
                          label: Text('Home'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.storage_outlined),
                          selectedIcon: Icon(Icons.storage),
                          label: Text('Profiles'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.settings_outlined),
                          selectedIcon: Icon(Icons.settings),
                          label: Text('Settings'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.tune_outlined),
                          selectedIcon: Icon(Icons.tune),
                          label: Text('Advanced'),
                        ),
                      ],
                    ),
                    const VerticalDivider(width: 24),
                    Expanded(
                      child: IndexedStack(
                        index: _selectedIndex,
                        children: pages,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
