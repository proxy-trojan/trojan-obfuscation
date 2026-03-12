import 'package:flutter/material.dart';

import '../../../platform/services/service_registry.dart';
import '../../diagnostics/presentation/diagnostics_page.dart';
import '../../packaging/presentation/packaging_page.dart';

class AdvancedPage extends StatelessWidget {
  const AdvancedPage({super.key, required this.services});

  final ClientServiceRegistry services;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Use Advanced only when you are checking a problem or reviewing update details.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          const TabBar(
            isScrollable: true,
            tabs: <Widget>[
              Tab(text: 'Problem Report'),
              Tab(text: 'Update Status'),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                SingleChildScrollView(child: DiagnosticsPage(services: services)),
                SingleChildScrollView(child: PackagingPage(services: services)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
