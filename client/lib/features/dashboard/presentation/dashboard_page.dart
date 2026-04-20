import 'package:flutter/material.dart';

import '../../../core/utils/format_timestamp.dart';
import '../../../core/widgets/key_value_pair.dart';
import '../../../core/widgets/section_card.dart';
import '../../../platform/services/desktop_lifecycle_models.dart';
import '../../../platform/services/service_registry.dart';
import '../../controller/domain/client_connection_status.dart';
import '../../controller/domain/controller_runtime_session.dart';
import '../../controller/domain/runtime_action_feedback.dart';
import '../../controller/domain/runtime_action_safety.dart';
import '../../controller/domain/runtime_operator_advice.dart';
import '../../controller/domain/runtime_posture.dart';
import 'dashboard_guide_policy.dart';
import '../../profiles/domain/client_profile.dart';
import '../../readiness/domain/readiness_refresh_fingerprint.dart';
import '../../readiness/domain/readiness_report.dart';
import '../../readiness/presentation/readiness_surface_controller.dart';
import '../application/connection_lifecycle_view_model.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.services,
    this.onOpenProfiles,
    this.onOpenAdvanced,
    this.onOpenSettings,
  });

  final ClientServiceRegistry services;
  final VoidCallback? onOpenProfiles;
  final VoidCallback? onOpenAdvanced;
  final VoidCallback? onOpenSettings;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final ReadinessSurfaceController _readinessController;

  @override
  void initState() {
    super.initState();
    _readinessController = ReadinessSurfaceController(
      isMounted: () => mounted,
      applyState: setState,
    );
    final services = widget.services;
    final profile = services.profileStore.selectedProfile;
    _readinessController.initialize(
      refreshKey: _buildReadinessRefreshKey(
        profile: profile,
        activeProfileId: services.controller.status.activeProfileId,
        storageSummary: services.profileSecrets.storageSummary,
        runtimeMode: services.controller.runtimeConfig.mode,
        runtimeEndpointHint: services.controller.runtimeConfig.endpointHint,
      ),
      restoreReport: () =>
          services.readiness.readLastKnownReport(profileOverride: profile),
      buildReport: () =>
          services.readiness.buildReport(profileOverride: profile),
    );
  }

  String _buildReadinessRefreshKey({
    required ClientProfile? profile,
    required String? activeProfileId,
    required String storageSummary,
    required String runtimeMode,
    required String runtimeEndpointHint,
  }) {
    return [
      buildReadinessRefreshFingerprint(
        profile: profile,
        storageSummary: storageSummary,
        runtimeMode: runtimeMode,
        runtimeEndpointHint: runtimeEndpointHint,
      ),
      'active:$activeProfileId',
    ].join('|');
  }

  void _refreshReadinessIfInputsChanged(String key, {ClientProfile? profile}) {
    _readinessController.refreshIfKeyChanged(
      key,
      restoreReport: () => widget.services.readiness
          .readLastKnownReport(profileOverride: profile),
      buildReport: () =>
          widget.services.readiness.buildReport(profileOverride: profile),
    );
  }

  VoidCallback? _actionHandlerFor(ReadinessAction action) {
    return switch (action) {
      ReadinessAction.openProfiles => widget.onOpenProfiles,
      ReadinessAction.openTroubleshooting => widget.onOpenAdvanced,
      ReadinessAction.openSettings => widget.onOpenSettings,
    };
  }

  @override
  Widget build(BuildContext context) {
    final services = widget.services;
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        services.profileStore,
        services.controller,
        services.settingsStore,
        services.desktopLifecycle,
      ]),
      builder: (BuildContext context, _) {
        final selectedProfile = services.profileStore.selectedProfile;
        final status = services.controller.status;
        final activeProfile =
            services.profileStore.profileById(status.activeProfileId);
        final lifecycleProfile = activeProfile ?? selectedProfile;
        final lifecycle = ConnectionLifecycleViewModel.fromStatus(
          status: status,
          selectedProfile: lifecycleProfile,
        );
        final runtimeConfig = services.controller.runtimeConfig;
        final telemetry = services.controller.telemetry;
        final desktopLifecycleStatus = services.desktopLifecycle.status;
        final readinessRefreshKey = _buildReadinessRefreshKey(
          profile: selectedProfile,
          activeProfileId: activeProfile?.id,
          storageSummary: services.profileSecrets.storageSummary,
          runtimeMode: runtimeConfig.mode,
          runtimeEndpointHint: runtimeConfig.endpointHint,
        );
        _refreshReadinessIfInputsChanged(
          readinessRefreshKey,
          profile: selectedProfile,
        );

        return ListView(
          children: <Widget>[
            if (desktopLifecycleStatus
                .isRecentExternalActivation()) ...<Widget>[
              _ExternalActivationCard(
                status: desktopLifecycleStatus,
                onDismiss: () {
                  services.desktopLifecycle.clearExternalActivation();
                },
                onOpenSettings: widget.onOpenSettings,
              ),
              const SizedBox(height: 16),
            ],
            if (selectedProfile == null && activeProfile == null)
              _StateCalloutCard(
                icon: Icons.playlist_add,
                title: 'Add one profile to get started',
                body:
                    'The first useful step is simple: create or import one profile, then save its password and try one connection.',
                primaryLabel: 'Open Profiles',
                onPrimary: widget.onOpenProfiles,
              )
            else if (activeProfile == null &&
                selectedProfile != null &&
                !selectedProfile.hasStoredPassword)
              _StateCalloutCard(
                icon: Icons.password,
                title: 'Save the password before testing',
                body:
                    'This profile is almost ready. Save the password first, then try one connection attempt.',
                primaryLabel: 'Open Profiles',
                onPrimary: widget.onOpenProfiles,
              )
            else
              _ConnectionHomeCard(
                lifecycle: lifecycle,
                selectedProfile: selectedProfile ?? lifecycleProfile!,
                activeProfile: activeProfile,
                status: status,
                runtimeMode: runtimeConfig.mode,
                controllerBackend: telemetry.backendKind,
                controllerVersion: telemetry.backendVersion,
                updateChannel:
                    services.settingsStore.settings.updateChannel.name,
                storageSummary: services.profileSecrets.storageSummary,
                onOpenProfiles: widget.onOpenProfiles,
                onOpenAdvanced: widget.onOpenAdvanced,
              ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'What to do next',
              subtitle:
                  'The app should guide the user, not make them read the system.',
              child: _NextStepGuide(
                services: services,
                selectedProfile: selectedProfile,
                activeProfile: activeProfile,
                status: status,
                lifecycle: lifecycle,
                readiness: _readinessController.latestReport,
                onOpenProfiles: widget.onOpenProfiles,
                onOpenAdvanced: widget.onOpenAdvanced,
                onOpenSettings: widget.onOpenSettings,
              ),
            ),
            const SizedBox(height: 16),
            if (_showExperimentGuide(
                selectedProfile ?? activeProfile, status)) ...<Widget>[
              const SectionCard(
                title: 'Experiment quick start',
                subtitle:
                    'Keep the workflow short and obvious when you are testing.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('1. Go to Profiles and create or import one profile.'),
                    SizedBox(height: 8),
                    Text('2. Save the Trojan password for that profile.'),
                    SizedBox(height: 8),
                    Text(
                        '3. Try one connect attempt and watch the status only.'),
                    SizedBox(height: 8),
                    Text(
                        '4. If it fails, open Advanced → Troubleshooting and export the bundle.'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            SectionCard(
              title: 'Readiness doctor',
              subtitle:
                  'Know if the app is ready, degraded, or blocked before connecting.',
              trailing: IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh readiness',
                onPressed: () => _readinessController.startCycle(
                  restoreReport: () => widget.services.readiness
                      .readLastKnownReport(profileOverride: selectedProfile),
                  buildReport: () => widget.services.readiness
                      .buildReport(profileOverride: selectedProfile),
                ),
              ),
              child: FutureBuilder<ReadinessReport>(
                future: _readinessController.future,
                builder: (BuildContext context,
                    AsyncSnapshot<ReadinessReport> snapshot) {
                  final report =
                      snapshot.data ?? _readinessController.latestReport;
                  if (report == null) {
                    return const Text('Checking readiness…');
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Wrap(
                        spacing: 24,
                        runSpacing: 12,
                        children: <Widget>[
                          KeyValuePair(
                            label: 'Overall',
                            value: report.overallLevel.label,
                          ),
                          KeyValuePair(
                              label: 'Headline', value: report.headline),
                          KeyValuePair(label: 'Summary', value: report.summary),
                          KeyValuePair(
                            label: 'Runtime Mode',
                            value: runtimeConfig.mode,
                          ),
                          KeyValuePair(
                            label: 'Runtime Endpoint',
                            value: runtimeConfig.endpointHint,
                          ),
                          KeyValuePair(
                            label: 'Secure Storage',
                            value: services.profileSecrets.storageSummary,
                          ),
                          KeyValuePair(
                            label: 'Readiness Provenance',
                            value: report.provenanceSummary,
                          ),
                        ],
                      ),
                      if (report.isCachedSnapshot &&
                          snapshot.connectionState !=
                              ConnectionState.done) ...<Widget>[
                        const SizedBox(height: 12),
                        const Text(
                          'Showing a cached snapshot while the live readiness refresh runs.',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                      if (report.recommendation != null) ...<Widget>[
                        const SizedBox(height: 12),
                        Text(
                          report.recommendation!.detail,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed:
                              _actionHandlerFor(report.recommendation!.action),
                          icon: const Icon(Icons.play_arrow),
                          label: Text(report.recommendation!.label),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 24,
                        runSpacing: 12,
                        children: report.checks
                            .map(
                              (check) => KeyValuePair(
                                label: check.domain.name,
                                value: '${check.level.label}: ${check.summary}',
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            ExpansionTile(
              title: const Text('Advanced runtime session'),
              subtitle: const Text('PID / logs / exit details for debugging.'),
              children: <Widget>[
                SectionCard(
                  title: 'Runtime Session',
                  child: _RuntimeSessionSummary(services: services),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  bool _showExperimentGuide(
      ClientProfile? profile, ClientConnectionStatus status) {
    if (profile == null) return true;
    if (!profile.hasStoredPassword) return true;
    return status.phase != ClientConnectionPhase.connected &&
        status.phase != ClientConnectionPhase.disconnecting;
  }
}

class _ExternalActivationCard extends StatelessWidget {
  const _ExternalActivationCard({
    required this.status,
    required this.onDismiss,
    this.onOpenSettings,
  });

  final DesktopLifecycleStatus status;
  final VoidCallback onDismiss;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Recent desktop activation',
      subtitle:
          'Make duplicate-launch and focus handoff behavior visible instead of leaving it hidden in the background.',
      trailing: TextButton.icon(
        onPressed: onDismiss,
        icon: const Icon(Icons.close),
        label: const Text('Dismiss'),
      ),
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
              status.externalActivationHeadline(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.deepPurple,
                  ),
            ),
            const SizedBox(height: 8),
            Text(status.externalActivationGuidance()),
            const SizedBox(height: 8),
            Text(
              'Observed at: ${formatTimestamp(status.lastExternalActivationAt)}',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _ActivationFactPill(
                  label: status.singleInstancePrimary
                      ? 'Single-instance guard active'
                      : 'Secondary instance handoff',
                ),
                _ActivationFactPill(
                  label: status.trayReady
                      ? 'Tray integration ready'
                      : 'Tray integration unavailable',
                ),
                _ActivationFactPill(
                  label: status.closeInterceptEnabled
                      ? 'Close interception enabled'
                      : 'Close interception disabled',
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Why you are seeing this: the app prevented a duplicate desktop session and handed focus back to the window that was already running.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (onOpenSettings != null)
                  OutlinedButton.icon(
                    onPressed: onOpenSettings,
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Review desktop behavior'),
                  ),
                TextButton.icon(
                  onPressed: onDismiss,
                  icon: const Icon(Icons.done),
                  label: const Text('Got it'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'This reminder auto-hides after a short window so the dashboard does not keep stale activation noise around forever.',
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivationFactPill extends StatelessWidget {
  const _ActivationFactPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.deepPurple.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.25)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.deepPurple,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _NextStepGuide extends StatelessWidget {
  const _NextStepGuide({
    required this.services,
    required this.selectedProfile,
    required this.activeProfile,
    required this.status,
    required this.lifecycle,
    required this.readiness,
    required this.onOpenProfiles,
    required this.onOpenAdvanced,
    this.onOpenSettings,
  });

  final ClientServiceRegistry services;
  final ClientProfile? selectedProfile;
  final ClientProfile? activeProfile;
  final ClientConnectionStatus status;
  final ConnectionLifecycleViewModel lifecycle;
  final ReadinessReport? readiness;
  final VoidCallback? onOpenProfiles;
  final VoidCallback? onOpenAdvanced;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final model = _model();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(model.title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(model.body),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.indigo.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.indigo.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Action safety',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(model.actionSafety.label),
              const SizedBox(height: 4),
              Text(model.actionSafety.detail),
            ],
          ),
        ),
        if (model.operatorTitle != null &&
            model.operatorBody != null) ...<Widget>[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  model.operatorTitle!,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(model.operatorBody!),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            FilledButton(
              onPressed: () => _runAction(context, model.primaryAction),
              child: Text(model.primaryLabel),
            ),
            if (model.secondaryLabel != null)
              OutlinedButton(
                onPressed: () => _runAction(context, model.secondaryAction),
                child: Text(model.secondaryLabel!),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _runAction(BuildContext context, _GuideAction? action) async {
    if (action == null) return;

    switch (action) {
      case _GuideAction.openProfiles:
        onOpenProfiles?.call();
        return;
      case _GuideAction.openAdvanced:
        onOpenAdvanced?.call();
        return;
      case _GuideAction.openSettings:
        onOpenSettings?.call();
        return;
      case _GuideAction.connectNow:
      case _GuideAction.retryNow:
        final currentProfile = action == _GuideAction.retryNow
            ? (activeProfile ?? selectedProfile)
            : selectedProfile;
        if (currentProfile == null) return;
        final readinessReport = await services.readiness
            .buildReport(profileOverride: currentProfile);
        if (!context.mounted) return;
        if (readinessReport.overallLevel == ReadinessLevel.blocked) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Connect blocked: ${readinessReport.summary}')),
          );
          return;
        }
        final result = await services.controller.connect(currentProfile);
        if (!context.mounted) return;
        final feedback = buildRuntimeActionFeedback(
          action: action == _GuideAction.retryNow
              ? RuntimeActionKind.retry
              : RuntimeActionKind.connect,
          result: result,
          status: services.controller.status,
          session: services.controller.session,
          posture: describeRuntimePosture(
            runtimeMode: services.controller.runtimeConfig.mode,
            backendKind: services.controller.telemetry.backendKind,
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(feedback)),
        );
        return;
      case _GuideAction.disconnectNow:
        final result = await services.controller.disconnect();
        if (!context.mounted) return;
        final feedback = buildRuntimeActionFeedback(
          action: RuntimeActionKind.disconnect,
          result: result,
          status: services.controller.status,
          session: services.controller.session,
          posture: describeRuntimePosture(
            runtimeMode: services.controller.runtimeConfig.mode,
            backendKind: services.controller.telemetry.backendKind,
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(feedback)),
        );
        return;
    }
  }

  _GuideModel _model() {
    final posture = describeRuntimePosture(
      runtimeMode: services.controller.runtimeConfig.mode,
      backendKind: services.controller.telemetry.backendKind,
    );
    final runtimeSession = services.controller.session;
    final operatorAdvice = RuntimeOperatorAdvice.resolve(
      status: status,
      session: runtimeSession,
      posture: posture,
      troubleshootingAvailable: onOpenAdvanced != null,
    );

    final policy = DashboardGuidePolicy.resolve(
      lifecycle: lifecycle,
      selectedProfile: selectedProfile,
      activeProfile: activeProfile,
      status: status,
      posture: posture,
      runtimeSession: runtimeSession,
      operatorAdvice: operatorAdvice,
      readiness: readiness,
      settingsAvailable: onOpenSettings != null,
    );

    return _GuideModel(
      title: policy.title,
      body: policy.body,
      primaryLabel: policy.primaryLabel,
      primaryAction: _mapGuideAction(policy.primaryAction),
      secondaryLabel: policy.secondaryLabel,
      secondaryAction: policy.secondaryAction == null
          ? null
          : _mapGuideAction(policy.secondaryAction!),
      operatorTitle: policy.operatorTitle,
      operatorBody: policy.operatorBody,
      actionSafety: policy.actionSafety,
    );
  }

  _GuideAction _mapGuideAction(DashboardGuideAction action) {
    return switch (action) {
      DashboardGuideAction.openProfiles => _GuideAction.openProfiles,
      DashboardGuideAction.openAdvanced => _GuideAction.openAdvanced,
      DashboardGuideAction.openSettings => _GuideAction.openSettings,
      DashboardGuideAction.connectNow => _GuideAction.connectNow,
      DashboardGuideAction.retryNow => _GuideAction.retryNow,
      DashboardGuideAction.disconnectNow => _GuideAction.disconnectNow,
    };
  }
}

enum _GuideAction {
  openProfiles,
  openAdvanced,
  openSettings,
  connectNow,
  retryNow,
  disconnectNow,
}

class _GuideModel {
  const _GuideModel({
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.primaryAction,
    required this.actionSafety,
    this.secondaryLabel,
    this.secondaryAction,
    this.operatorTitle,
    this.operatorBody,
  });

  final String title;
  final String body;
  final String primaryLabel;
  final _GuideAction primaryAction;
  final RuntimeActionSafety actionSafety;
  final String? secondaryLabel;
  final _GuideAction? secondaryAction;
  final String? operatorTitle;
  final String? operatorBody;
}

class _ConnectionHomeCard extends StatelessWidget {
  const _ConnectionHomeCard({
    required this.lifecycle,
    required this.selectedProfile,
    required this.activeProfile,
    required this.status,
    required this.runtimeMode,
    required this.controllerBackend,
    required this.controllerVersion,
    required this.updateChannel,
    required this.storageSummary,
    required this.onOpenProfiles,
    required this.onOpenAdvanced,
  });

  final ConnectionLifecycleViewModel lifecycle;
  final ClientProfile selectedProfile;
  final ClientProfile? activeProfile;
  final ClientConnectionStatus status;
  final String runtimeMode;
  final String controllerBackend;
  final String controllerVersion;
  final String updateChannel;
  final String storageSummary;
  final VoidCallback? onOpenProfiles;
  final VoidCallback? onOpenAdvanced;

  Color get _accentColor => switch (lifecycle.stage) {
        ConnectionLifecycleStage.idle => Colors.blue,
        ConnectionLifecycleStage.connecting => Colors.orange,
        ConnectionLifecycleStage.connected => Colors.green,
        ConnectionLifecycleStage.disconnecting => Colors.orange,
        ConnectionLifecycleStage.error => Colors.red,
      };

  @override
  Widget build(BuildContext context) {
    final posture = describeRuntimePosture(
      runtimeMode: runtimeMode,
      backendKind: controllerBackend,
    );

    return SectionCard(
      title: 'Connection Home',
      subtitle:
          'The primary path should be obvious: profile → password → connect.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _accentColor.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            lifecycle.headline,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(lifecycle.detail),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _LifecyclePill(
                      label: lifecycle.label,
                      color: _accentColor,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  children: <Widget>[
                    KeyValuePair(label: 'Lifecycle', value: lifecycle.label),
                    KeyValuePair(
                        label: 'Selected Profile', value: selectedProfile.name),
                    KeyValuePair(
                      label: 'Active Profile',
                      value: activeProfile?.name ??
                          lifecycle.activeProfileName ??
                          'None',
                    ),
                    KeyValuePair(
                        label: 'Status Note', value: lifecycle.statusSummary),
                    KeyValuePair(
                        label: 'Secret Storage', value: storageSummary),
                    KeyValuePair(label: 'Runtime Mode', value: runtimeMode),
                    KeyValuePair(
                      label: 'Runtime Posture',
                      value: posture.postureLabel,
                    ),
                    KeyValuePair(
                      label: 'Evidence Grade',
                      value: posture.evidenceGradeLabel,
                    ),
                    KeyValuePair(
                      label: 'Execution Path',
                      value: posture.executionPathLabel,
                    ),
                    KeyValuePair(
                        label: 'Controller Backend', value: controllerBackend),
                    KeyValuePair(
                        label: 'Backend Version', value: controllerVersion),
                    KeyValuePair(label: 'Update Channel', value: updateChannel),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '${posture.truthNote} ${posture.evidenceGradeNote}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    if (lifecycle.showRetry)
                      FilledButton.icon(
                        onPressed: lifecycle.canConnect ? onOpenProfiles : null,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry from Profiles'),
                      ),
                    if (lifecycle.showOpenProfiles)
                      OutlinedButton.icon(
                        onPressed: onOpenProfiles,
                        icon: const Icon(Icons.list_alt),
                        label: const Text('Open Profiles'),
                      ),
                    if (lifecycle.showOpenTroubleshooting)
                      OutlinedButton.icon(
                        onPressed: onOpenAdvanced,
                        icon: const Icon(Icons.build_circle_outlined),
                        label: const Text('Open Troubleshooting'),
                      ),
                    OutlinedButton.icon(
                      onPressed: onOpenAdvanced,
                      icon: const Icon(Icons.assignment_outlined),
                      label: const Text('Problem Report'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LifecyclePill extends StatelessWidget {
  const _LifecyclePill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Connection status: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _StateCalloutCard extends StatelessWidget {
  const _StateCalloutCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.primaryLabel,
    this.onPrimary,
  });

  final IconData icon;
  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback? onPrimary;

  @override
  Widget build(BuildContext context) {
    const color = Colors.blue;

    return SectionCard(
      title: title,
      subtitle: 'User-facing guidance should be obvious and short.',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(body),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: onPrimary,
                  child: Text(primaryLabel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RuntimeTruthPill extends StatelessWidget {
  const _RuntimeTruthPill({
    required this.label,
    required this.highlighted,
  });

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final color = highlighted ? Colors.orange : Colors.blueGrey;

    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _RuntimeSessionSummary extends StatelessWidget {
  const _RuntimeSessionSummary({required this.services});

  final ClientServiceRegistry services;

  @override
  Widget build(BuildContext context) {
    // 使用 AnimatedBuilder 确保 ExpansionTile 展开后 session 变更仍能刷新
    return AnimatedBuilder(
      animation: services.controller,
      builder: (BuildContext context, _) {
        final session = services.controller.session;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: session.needsAttention
                    ? Colors.orange.withValues(alpha: 0.08)
                    : Colors.blue.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: session.needsAttention
                      ? Colors.orange.withValues(alpha: 0.25)
                      : Colors.blue.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      _RuntimeTruthPill(
                        label: 'Session Truth: ${session.truth.label}',
                        highlighted: session.needsAttention,
                      ),
                      _RuntimeTruthPill(
                        label: 'Updated ${session.ageLabel}',
                        highlighted: false,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    session.truthNote,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(session.recoveryGuidance),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: <Widget>[
                KeyValuePair(
                    label: 'Running', value: session.isRunning ? 'Yes' : 'No'),
                KeyValuePair(
                    label: 'Runtime Truth', value: session.truth.label),
                KeyValuePair(label: 'Snapshot Age', value: session.ageLabel),
                KeyValuePair(label: 'Runtime Phase', value: session.phase.name),
                KeyValuePair(
                  label: 'Stop Requested',
                  value: session.stopRequested ? 'Yes' : 'No',
                ),
                KeyValuePair(
                  label: 'Stop Requested At',
                  value: session.stopRequestedAt == null
                      ? 'N/A'
                      : formatTimestamp(session.stopRequestedAt!),
                ),
                KeyValuePair(
                    label: 'PID', value: session.pid?.toString() ?? 'N/A'),
                KeyValuePair(
                    label: 'Config Path',
                    value: session.activeConfigPath ?? 'N/A'),
                KeyValuePair(
                  label: 'Config Provenance',
                  value: session.configProvenance ?? 'N/A',
                ),
                KeyValuePair(
                  label: 'Expected Local SOCKS Port',
                  value: session.expectedLocalSocksPort?.toString() ?? 'N/A',
                ),
                KeyValuePair(
                  label: 'Launch Plan',
                  value: session.launchPlan?.summary ?? 'N/A',
                ),
                KeyValuePair(
                    label: 'Last Exit Code',
                    value: session.lastExitCode?.toString() ?? 'N/A'),
                KeyValuePair(
                    label: 'Last Error', value: session.lastError ?? 'None'),
              ],
            ),
            const SizedBox(height: 12),
            if (session.stdoutTail.isNotEmpty)
              _logTail('stdout tail', session.stdoutTail),
            if (session.stderrTail.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              _logTail('stderr tail', session.stderrTail),
            ],
          ],
        );
      },
    );
  }

  Widget _logTail(String label, List<String> lines) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(lines.join('\n')),
        ),
      ],
    );
  }
}
