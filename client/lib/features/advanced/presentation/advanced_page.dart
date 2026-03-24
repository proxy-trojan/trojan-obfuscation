import 'package:flutter/material.dart';

import '../../../core/utils/format_timestamp.dart';
import '../../../core/widgets/key_value_pair.dart';
import '../../../core/widgets/section_card.dart';
import '../../../platform/services/app_runtime_error_store.dart';
import '../../../platform/services/service_registry.dart';
import '../../controller/domain/client_connection_status.dart';
import '../../controller/domain/last_runtime_failure_summary.dart';
import '../../controller/domain/runtime_posture.dart';
import '../../diagnostics/application/support_issue_descriptor.dart';
import '../../diagnostics/presentation/diagnostics_page.dart';
import '../../packaging/presentation/packaging_page.dart';

enum AdvancedPageTab {
  problemReport,
  updateStatus,
}

class AdvancedPage extends StatefulWidget {
  const AdvancedPage({
    super.key,
    required this.services,
    this.requestedTab = AdvancedPageTab.problemReport,
    this.tabRequestId = 0,
  });

  final ClientServiceRegistry services;
  final AdvancedPageTab requestedTab;
  final int tabRequestId;

  @override
  State<AdvancedPage> createState() => _AdvancedPageState();
}

class _AdvancedPageState extends State<AdvancedPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int? _lastHandledTabRequestId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: _tabIndexFor(widget.requestedTab),
    );
    _lastHandledTabRequestId = widget.tabRequestId;
  }

  @override
  void didUpdateWidget(covariant AdvancedPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tabRequestId == _lastHandledTabRequestId) {
      return;
    }
    _lastHandledTabRequestId = widget.tabRequestId;
    _tabController.animateTo(_tabIndexFor(widget.requestedTab));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int _tabIndexFor(AdvancedPageTab tab) {
    return switch (tab) {
      AdvancedPageTab.problemReport => 0,
      AdvancedPageTab.updateStatus => 1,
    };
  }

  @override
  Widget build(BuildContext context) {
    final services = widget.services;
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        services.controller,
        services.appRuntimeErrors,
        services.packagingStore,
      ]),
      builder: (BuildContext context, _) {
        final status = services.controller.status;
        final runtimeConfig = services.controller.runtimeConfig;
        final telemetry = services.controller.telemetry;
        final issue = SupportIssueDescriptor.fromConnectionStatus(status);
        final lastRuntimeFailure = services.controller.lastRuntimeFailure;
        final appUnhandledError = services.appRuntimeErrors.lastUnhandledError;

        return NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return <Widget>[
              SliverToBoxAdapter(
                child: Text(
                  'Use Advanced when you need a support-oriented overview, a problem report bundle, or update/package details.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(
                child: _SupportOverviewCard(
                  status: status,
                  issue: issue,
                  runtimeMode: runtimeConfig.mode,
                  endpointHint: runtimeConfig.endpointHint,
                  backendKind: telemetry.backendKind,
                  backendVersion: telemetry.backendVersion,
                  diagnosticsBackend:
                      services.diagnosticsFileExporter.backendName,
                  lastRuntimeFailure: lastRuntimeFailure,
                  appUnhandledError: appUnhandledError,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverToBoxAdapter(
                child: _SupportActionsCard(
                  status: status,
                  onOpenProblemReport: () => _tabController.animateTo(0),
                  onOpenUpdateStatus: () => _tabController.animateTo(1),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverToBoxAdapter(
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabs: const <Widget>[
                    Tab(text: 'Problem Report'),
                    Tab(text: 'Update Status'),
                  ],
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: <Widget>[
              DiagnosticsPage(services: services),
              PackagingPage(services: services),
            ],
          ),
        );
      },
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
    required this.appUnhandledError,
  });

  final ClientConnectionStatus status;
  final SupportIssueDescriptor issue;
  final String runtimeMode;
  final String endpointHint;
  final String backendKind;
  final String backendVersion;
  final String diagnosticsBackend;
  final LastRuntimeFailureSummary? lastRuntimeFailure;
  final AppUnhandledErrorSummary? appUnhandledError;

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
    final posture = describeRuntimePosture(
      runtimeMode: runtimeMode,
      backendKind: backendKind,
    );

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
          if (appUnhandledError != null) ...<Widget>[
            const SizedBox(height: 12),
            _AppUnhandledErrorBanner(summary: appUnhandledError!),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: <Widget>[
              KeyValuePair(
                  label: 'Connection phase',
                  value: status.phase.name,
                  width: 240),
              KeyValuePair(
                  label: 'Status note', value: status.message, width: 240),
              KeyValuePair(
                  label: 'Runtime mode', value: runtimeMode, width: 240),
              KeyValuePair(
                label: 'Runtime posture',
                value: posture.postureLabel,
                width: 240,
              ),
              KeyValuePair(
                label: 'Evidence grade',
                value: posture.evidenceGradeLabel,
                width: 240,
              ),
              KeyValuePair(
                label: 'Execution path',
                value: posture.executionPathLabel,
                width: 240,
              ),
              KeyValuePair(
                  label: 'Endpoint hint', value: endpointHint, width: 240),
              KeyValuePair(label: 'Backend', value: backendKind, width: 240),
              KeyValuePair(
                  label: 'Backend version', value: backendVersion, width: 240),
              KeyValuePair(
                  label: 'Diagnostics export',
                  value: diagnosticsBackend,
                  width: 240),
              KeyValuePair(
                  label: 'Issue category', value: issue.label, width: 240),
              KeyValuePair(
                  label: 'Support summary', value: issue.summary, width: 240),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${posture.truthNote} ${posture.evidenceGradeNote}',
            style: const TextStyle(fontWeight: FontWeight.w600),
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
    return Semantics(
      label: 'Runtime error: ${summary.headline}',
      child: Container(
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
            Text('Recorded at: ${formatTimestamp(summary.recordedAt)}'),
          ],
        ),
      ),
    );
  }
}

class _AppUnhandledErrorBanner extends StatelessWidget {
  const _AppUnhandledErrorBanner({required this.summary});

  final AppUnhandledErrorSummary summary;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Uncaught error: ${summary.message}',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.deepPurple.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Last uncaught app error',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.deepPurple,
                  ),
            ),
            const SizedBox(height: 8),
            Text(summary.message),
            const SizedBox(height: 6),
            Text('Source: ${summary.source}'),
            const SizedBox(height: 6),
            Text(summary.stackPreview),
            const SizedBox(height: 6),
            Text('Recorded at: ${formatTimestamp(summary.recordedAt)}'),
          ],
        ),
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
    return Semantics(
      label: 'Issue category: ${issue.label}, ${issue.headline}',
      child: Container(
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
