import 'package:flutter/material.dart';

import '../features/advanced/presentation/advanced_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/profiles/presentation/profiles_page.dart';
import '../features/readiness/domain/readiness_report.dart';
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
  int _advancedTabRequestId = 0;
  AdvancedPageTab _requestedAdvancedTab = AdvancedPageTab.problemReport;
  DateTime? _lastHandledExternalActivationAt;

  @override
  void initState() {
    super.initState();
    widget.services.desktopLifecycle
        .addListener(_handleDesktopLifecycleChanged);
    // initialize() 已在 bootstrap 阶段完成，此处不再重复调用
  }

  @override
  void dispose() {
    widget.services.desktopLifecycle
        .removeListener(_handleDesktopLifecycleChanged);
    // 不在此处调用 desktopLifecycle.disposeService()——
    // desktopLifecycle 是 ServiceRegistry 中的共享单例，
    // 其生命周期由 app 级别管理，而非由单个 widget 的 dispose 控制。
    super.dispose();
  }

  void _handleDesktopLifecycleChanged() {
    final status = widget.services.desktopLifecycle.status;
    if (!status.isRecentExternalActivation()) {
      return;
    }

    final activatedAt = status.lastExternalActivationAt;
    if (activatedAt == null ||
        activatedAt == _lastHandledExternalActivationAt) {
      return;
    }

    _lastHandledExternalActivationAt = activatedAt;
    if (_selectedIndex != 0 && mounted) {
      setState(() => _selectedIndex = 0);
    }
  }

  void _openAdvanced([AdvancedPageTab tab = AdvancedPageTab.problemReport]) {
    setState(() {
      _selectedIndex = 3;
      _requestedAdvancedTab = tab;
      _advancedTabRequestId++;
    });
  }

  /// 窄屏断点：低于此宽度使用 BottomNavigationBar 代替 NavigationRail。
  static const double _compactBreakpoint = 600;

  // 使用 ValueKey 保持各 page 的 State 在宽窄屏切换时不被销毁重建
  static const List<ValueKey<String>> _pageKeys = <ValueKey<String>>[
    ValueKey<String>('dashboard'),
    ValueKey<String>('profiles'),
    ValueKey<String>('settings'),
    ValueKey<String>('advanced'),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DashboardPage(
        key: _pageKeys[0],
        services: widget.services,
        onOpenProfiles: () => setState(() => _selectedIndex = 1),
        onOpenAdvanced: () => _openAdvanced(),
        onOpenSettings: () => setState(() => _selectedIndex = 2),
      ),
      ProfilesPage(
        key: _pageKeys[1],
        services: widget.services,
        onOpenAdvanced: (ReadinessAction action) {
          switch (action) {
            case ReadinessAction.openTroubleshooting:
              _openAdvanced(AdvancedPageTab.problemReport);
              return;
            case ReadinessAction.openProfiles:
            case ReadinessAction.openSettings:
              _openAdvanced();
              return;
          }
        },
        onOpenSettings: () => setState(() => _selectedIndex = 2),
      ),
      SettingsPage(key: _pageKeys[2], services: widget.services),
      AdvancedPage(
        key: _pageKeys[3],
        services: widget.services,
        requestedTab: _requestedAdvancedTab,
        tabRequestId: _advancedTabRequestId,
      ),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final useBottomNav = constraints.maxWidth < _compactBreakpoint;

        final pageContent = IndexedStack(
          index: _selectedIndex,
          children: pages,
        );

        if (useBottomNav) {
          return Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: pageContent,
              ),
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (int index) {
                setState(() => _selectedIndex = index);
              },
              destinations: const <NavigationDestination>[
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.storage_outlined),
                  selectedIcon: Icon(Icons.storage),
                  label: 'Profiles',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
                NavigationDestination(
                  icon: Icon(Icons.tune_outlined),
                  selectedIcon: Icon(Icons.tune),
                  label: 'Advanced',
                ),
              ],
            ),
          );
        }

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
                        Expanded(child: pageContent),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
