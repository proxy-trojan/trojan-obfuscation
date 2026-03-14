import 'package:flutter/material.dart';

import '../../../core/widgets/section_card.dart';
import '../../../platform/services/service_registry.dart';
import '../../controller/domain/client_connection_status.dart';
import '../../controller/domain/last_runtime_failure_summary.dart';
import '../../diagnostics/application/support_issue_descriptor.dart';
import '../../diagnostics/presentation/diagnostics_page.dart';
import '../../packaging/presentation/packaging_page.dart';

class AdvancedPage extends StatelessWidget {
  const AdvancedPage({super.key, required this.services});

  final ClientServiceRegistry services;

  @override
  Widget build(BuildContext context) {
    final status = services.controller.status;
    final runtimeConfig = services.controller.runtimeConfig;
    final telemetry = services.controller.telemetry;

    return DefaultTabController(
      length: 2,
      child: Builder(
        builder: (BuildContext context) {
          final tabController = DefaultTabController.of(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Use Advanced when you need a support-oriented overview, a problem report bundle, or update/package details.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              _SupportOverviewCard(
                status: status,
                runtimeMode: runtimeConfig.mode,
                endpointHint: runtimeConfig.endpointHint,
                backendKind: telemetry.backendKind,
                backendVersion: telemetry.backendVersion,
                diagnosticsBackend:
                    services.diagnosticsFileExporter.backendName,
              ),
              const SizedBox(height: 16),
              _SupportActionsCard(
                status: status,
                onOpenProblemReport: () => tabController.animateTo(0),
                onOpenUpdateStatus: () => tabController.animateTo(1),
              ),
              const SizedBox(height: 16),
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
                    SingleChildScrollView(
                      child: DiagnosticsPage(services: services),
                    ),
                    SingleChildScrollView(
                      child: PackagingPage(services: services),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SupportOverviewCard extends StatelessWidget {
  const _SupportOverviewCard({
    required this.status,
    required this.issue,
    required this.runtimeMode,
    required this.endpointHint,
    required this.backendKind,
    required this.backendVersion,
    required this.diagnosticsBackend,
    required this.lastRuntimeFailure,
  });

  final ClientConnectionStatus status;
  final SupportIssueDescriptor issue;
  final String runtimeMode;
  final String endpointHint;
  final String backendKind;
  final String backendVersion;
  final String diagnosticsBackend;
  final LastRuntimeFailureSummary? lastRuntimeFailure;

  String get _headline {
    return switch (status.phase) {
      ClientConnectionPhase.disconnected => 'No active connection right now',
      ClientConnectionPhase.connecting => 'A connection attempt is running',
      ClientConnectionPhase.connected =>
        'The runtime session is currently active',
      ClientConnectionPhase.disconnecting =>
        'The current session is shutting down',
      ClientConnectionPhase.error => 'The last connection needs attention',
    };
  }

  String get _nextStep {
    return switch (status.phase) {
      ClientConnectionPhase.error =>
        'Start with Problem Report if you want a support-ready bundle for the latest failure.',
      ClientConnectionPhase.connected =>
        'If the connection still feels wrong, capture a problem report before disconnecting.',
      _ =>
        'Use this page when the lifecycle feels unclear or you need a support-ready snapshot.',
    };
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Troubleshooting Overview',
      subtitle:
          'Start here when you want a quick picture of what the client is doing right now.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _headline,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(_nextStep),
          const SizedBox(height: 16),
          _IssueCategoryBanner(issue: issue),
          if (lastRuntimeFailure != null) ...<Widget>[
            const SizedBox(height: 12),
            _LastRuntimeFailureBanner(summary: lastRuntimeFailure!),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: <Widget>[
              _kv('Connection phase', status.phase.name),
              _kv('Status note', status.message),
              _kv('Runtime mode', runtimeMode),
              _kv('Endpoint hint', endpointHint),
              _kv('Backend', backendKind),
              _kv('Backend version', backendVersion),
              _kv('Diagnostics export', diagnosticsBackend),
              _kv('Issue category', issue.label),
              _kv('Support summary', issue.summary),
            ],
          ),
        ],
      ),
    );
  }
}

class _LastRuntimeFailureBanner extends StatelessWidget {
  const _LastRuntimeFailureBanner({required this.summary});

  final LastRuntimeFailureSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Last recorded runtime failure',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700, color: Colors.red),
          ),
          const SizedBox(height: 8),
          Text(summary.headline),
          const SizedBox(height: 6),
          Text(summary.detail),
          const SizedBox(height: 6),
          Text('Phase: ${summary.phase}'),
          Text('Recorded at: ${summary.recordedAt.toIso8601String()}'),
        ],
      ),
    );
  }
}

class _IssueCategoryBanner extends StatelessWidget {
  const _IssueCategoryBanner({required this.issue});

  final SupportIssueDescriptor issue;

  Color _accent(BuildContext context) {
    return switch (issue.category) {
      SupportIssueCategory.userInput => Colors.blue,
      SupportIssueCategory.configuration => Colors.orange,
      SupportIssueCategory.runtime => Colors.red,
      SupportIssueCategory.osOrExport => Colors.deepPurple,
      SupportIssueCategory.none => Theme.of(context).colorScheme.primary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _accent(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Issue category: ${issue.label}',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700, color: color),
          ),
          const SizedBox(height: 8),
          Text(issue.headline),
          const SizedBox(height: 8),
          Text(issue.guidance),
        ],
      ),
    );
  }
}

class _SupportActionsCard extends StatelessWidget {
  const _SupportActionsCard({
    required this.status,
    required this.onOpenProblemReport,
    required this.onOpenUpdateStatus,
  });

  final ClientConnectionStatus status;
  final VoidCallback onOpenProblemReport;
  final VoidCallback onOpenUpdateStatus;

  String get _actionHint {
    return switch (status.phase) {
      ClientConnectionPhase.error =>
        'The last connection failed. Open Problem Report if you want a support bundle to share.',
      ClientConnectionPhase.connected =>
        'The session is active. Export a support bundle now if you need a snapshot before disconnecting.',
      _ =>
        'If you need help or want to share context, start with Problem Report.',
    };
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'What to try next',
      subtitle:
          'Use one clear next step instead of guessing which internal page matters.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(_actionHint),
          const SizedBox(height: 8),
          const Text(
            'Problem Report is the export/share path. Update Status is for packaging and release context.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.icon(
                onPressed: onOpenProblemReport,
                icon: const Icon(Icons.assignment_outlined),
                label: const Text('Open Problem Report'),
              ),
              OutlinedButton.icon(
                onPressed: onOpenUpdateStatus,
                icon: const Icon(Icons.system_update_alt_outlined),
                label: const Text('Review Update Status'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Widget _kv(String label, String value) {
  return SizedBox(
    width: 240,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(value),
      ],
    ),
  );
}
