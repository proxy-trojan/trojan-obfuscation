import 'package:flutter/material.dart';

import '../features/controller/domain/client_connection_status.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/diagnostics/presentation/diagnostics_page.dart';
import '../features/profiles/presentation/profiles_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../platform/services/service_registry.dart';

class ClientAppShell extends StatefulWidget {
  const ClientAppShell({super.key, required this.services});

  final ClientServiceRegistry services;

  @override
  State<ClientAppShell> createState() => _ClientAppShellState();
}

class _ClientAppShellState extends State<ClientAppShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DashboardPage(services: widget.services),
      ProfilesPage(services: widget.services),
      SettingsPage(services: widget.services),
      DiagnosticsPage(services: widget.services),
    ];

    final destinations = <NavigationRailDestination>[
      const NavigationRailDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard),
        label: Text('Dashboard'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.dns_outlined),
        selectedIcon: Icon(Icons.dns),
        label: Text('Profiles'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: Text('Settings'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.assignment_outlined),
        selectedIcon: Icon(Icons.assignment),
        label: Text('Diagnostics'),
      ),
    ];

    return AnimatedBuilder(
      animation: widget.services.controller,
      builder: (BuildContext context, _) {
        final status = widget.services.controller.status;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Trojan-Pro Client'),
            actions: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(child: _StatusChip(status: status)),
              ),
            ],
          ),
          body: Row(
            children: <Widget>[
              NavigationRail(
                selectedIndex: _selectedIndex,
                labelType: NavigationRailLabelType.all,
                onDestinationSelected: (int index) {
                  setState(() => _selectedIndex = index);
                },
                destinations: destinations,
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: pages[_selectedIndex],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ClientConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final Color color;
    switch (status.phase) {
      case ClientConnectionPhase.connected:
        color = Colors.green;
      case ClientConnectionPhase.connecting:
        color = Colors.orange;
      case ClientConnectionPhase.error:
        color = Colors.red;
      case ClientConnectionPhase.disconnected:
        color = Colors.grey;
    }

    return Chip(
      avatar: CircleAvatar(backgroundColor: color, radius: 6),
      label: Text(status.message),
    );
  }
}
