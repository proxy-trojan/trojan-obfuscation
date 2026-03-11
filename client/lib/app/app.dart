import 'package:flutter/material.dart';

import '../platform/services/service_registry.dart';
import 'app_shell.dart';

class TrojanClientApp extends StatelessWidget {
  const TrojanClientApp({super.key, required this.services});

  final ClientServiceRegistry services;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: services.settingsStore,
      builder: (BuildContext context, _) {
        final themeMode = services.settingsStore.settings.themeMode;

        return MaterialApp(
          title: 'Trojan-Pro Client',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.indigo,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          home: ClientAppShell(services: services),
        );
      },
    );
  }
}
