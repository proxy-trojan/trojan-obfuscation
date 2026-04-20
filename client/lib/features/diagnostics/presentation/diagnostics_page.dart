import 'package:flutter/material.dart';

import '../../../core/widgets/section_card.dart';
import '../../../platform/services/service_registry.dart';
import '../../controller/domain/controller_runtime_session.dart';
import '../../controller/domain/runtime_operator_advice.dart';
import '../../controller/domain/runtime_posture.dart';
import '../application/support_issue_descriptor.dart';
import '../domain/export_summary_snapshot.dart';
import '../../profiles/presentation/import_export_dialog.dart';
import 'diagnostics_support_policy.dart';
import 'export_summary_sheet.dart';

class DiagnosticsPage extends StatefulWidget {
  const DiagnosticsPage({super.key, required this.services});

  final ClientServiceRegistry services;

  @override
  State<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends State<DiagnosticsPage> {
  String _preview =
      'Press “Generate support preview” to build a support bundle payload.';
  String? _lastExportTarget;
  String? _lastExportKindLabel;
  SupportIssueDescriptor? _lastExportIssue;
  ControllerRuntimeSession? _lastExportRuntimeSession;
  DateTime? _lastExportCapturedAt;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final runtimePosture = describeRuntimePosture(
      runtimeMode: widget.services.controller.runtimeConfig.mode,
      backendKind: widget.services.controller.telemetry.backendKind,
    );
    final runtimeSession = widget.services.controller.session;
    final operatorAdvice = RuntimeOperatorAdvice.resolve(
      status: widget.services.controller.status,
      session: runtimeSession,
      posture: runtimePosture,
      troubleshootingAvailable: true,
    );

    final supportPolicy = DiagnosticsSupportPolicy.resolve(
      runtimeSession: runtimeSession,
      runtimePosture: runtimePosture,
      operatorAdvice: operatorAdvice,
      exportedRuntimeSession: _lastExportRuntimeSession,
      exportedBundleKindLabel: _lastExportKindLabel,
    );

    final exportSummary = ExportSummarySnapshot.fromContext(
      runtimePosture: runtimePosture,
      runtimeSession: runtimeSession,
      storageStatus: widget.services.profileSecrets.storageStatus,
    );

    return SingleChildScrollView(
      child: SectionCard(
        title: 'Problem Report',
        subtitle:
            'Create a support-ready snapshot when something goes wrong. Use this when you need to inspect a failure or share a support bundle. Export backend: ${widget.services.diagnosticsFileExporter.backendName}',
        trailing: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            OutlinedButton(
              onPressed: _preview.startsWith('Press “Generate')
                  ? null
                  : () => showExportTextDialog(
                        context,
                        title: 'Diagnostics Preview JSON',
                        text: _preview,
                      ),
              child: const Text('Open full JSON'),
            ),
            OutlinedButton.icon(
              onPressed: _preview.startsWith('Press “Generate') || _busy
                  ? null
                  : _exportSupportBundle,
              icon: const Icon(Icons.save_alt),
              label: const Text('Export support bundle'),
            ),
            if (runtimePosture.canProduceRuntimeProofArtifact)
              OutlinedButton.icon(
                onPressed: _preview.startsWith('Press “Generate') || _busy
                    ? null
                    : _exportRuntimeProofArtifact,
                icon: const Icon(Icons.verified_outlined),
                label: const Text('Export runtime-proof artifact'),
              ),
            FilledButton.icon(
              onPressed: _busy ? null : _generate,
              icon: const Icon(Icons.download),
              label: const Text('Generate support preview'),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _SupportBundleSummaryCard(
              exportBackend:
                  widget.services.diagnosticsFileExporter.backendName,
              runtimePosture: runtimePosture,
            ),
            const SizedBox(height: 12),
            ExportSummarySheet.fromSnapshot(exportSummary),
            const SizedBox(height: 16),
            _RuntimeTruthSupportCard(
              runtimeSession: runtimeSession,
              runtimePosture: runtimePosture,
              supportPolicy: supportPolicy,
              exportCapturedAt: _lastExportCapturedAt,
            ),
            const SizedBox(height: 16),
            if (_lastExportTarget != null) ...<Widget>[
              Text(
                'Last export target (${_lastExportKindLabel ?? 'support bundle'}): $_lastExportTarget',
              ),
              const SizedBox(height: 12),
            ],
            if (_lastExportIssue != null) ...<Widget>[
              _ExportIssueBanner(issue: _lastExportIssue!),
              const SizedBox(height: 12),
            ],
            Text(
              'Preview excerpt',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            SelectableText(_previewExcerpt(_preview)),
          ],
        ),
      ),
    );
  }

  String _previewExcerpt(String text) {
    const limit = 1200;
    if (text.length <= limit) return text;
    return '${text.substring(0, limit)}\n\n… truncated preview — use “Open full JSON” for the complete support bundle payload.';
  }

  Future<void> _generate() async {
    setState(() => _busy = true);
    try {
      final preview = await widget.services.diagnostics.buildPreviewBundle();
      final capturedSession = widget.services.controller.session;
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _lastExportIssue = null;
        _lastExportRuntimeSession = capturedSession;
        _lastExportCapturedAt = DateTime.now();
        _lastExportKindLabel = 'support preview';
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to generate diagnostics preview: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _exportSupportBundle() async {
    setState(() => _busy = true);
    try {
      final result = await widget.services.diagnostics.exportSupportBundle();
      final capturedSession = widget.services.controller.session;
      if (!mounted) return;
      setState(() {
        _preview = result.contents;
        _lastExportTarget = result.target;
        _lastExportKindLabel = 'support bundle';
        _lastExportIssue = null;
        _lastExportRuntimeSession = capturedSession;
        _lastExportCapturedAt = DateTime.now();
      });
    } catch (error) {
      if (!mounted) return;
      final issue = SupportIssueDescriptor.fromExportError(error);
      setState(() {
        _lastExportIssue = issue;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export diagnostics bundle: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _exportRuntimeProofArtifact() async {
    setState(() => _busy = true);
    try {
      final result =
          await widget.services.diagnostics.exportRuntimeProofArtifact();
      final capturedSession = widget.services.controller.session;
      if (!mounted) return;
      setState(() {
        _lastExportTarget = result.target;
        _lastExportKindLabel = 'runtime-proof artifact';
        _lastExportIssue = null;
        _lastExportRuntimeSession = capturedSession;
        _lastExportCapturedAt = DateTime.now();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Runtime-proof artifact exported to ${result.target}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final issue = SupportIssueDescriptor.fromExportError(error);
      setState(() {
        _lastExportIssue = issue;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export runtime-proof artifact: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}

class _ExportIssueBanner extends StatelessWidget {
  const _ExportIssueBanner({required this.issue});

  final SupportIssueDescriptor issue;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            issue.headline,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.deepPurple,
                ),
          ),
          const SizedBox(height: 6),
          Text(issue.guidance),
          const SizedBox(height: 6),
          Text('Failure family: ${issue.familyLabel}'),
          const SizedBox(height: 6),
          Text('Detail: ${issue.summary}'),
        ],
      ),
    );
  }
}

class _RuntimeTruthSupportCard extends StatelessWidget {
  const _RuntimeTruthSupportCard({
    required this.runtimeSession,
    required this.runtimePosture,
    required this.supportPolicy,
    this.exportCapturedAt,
  });

  final ControllerRuntimeSession runtimeSession;
  final RuntimePosture runtimePosture;
  final DiagnosticsSupportPolicy supportPolicy;
  final DateTime? exportCapturedAt;

  @override
  Widget build(BuildContext context) {
    final attentionColor = runtimeSession.needsAttention
        ? Colors.orange
        : Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: attentionColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: attentionColor.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Runtime truth & recovery',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Support output should explain whether the runtime looks live, stale, or residual before you export anything.',
          ),
          const SizedBox(height: 12),
          Text(
            supportPolicy.currentTruthTitle,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text('Snapshot age: ${runtimeSession.ageLabel}'),
          const SizedBox(height: 6),
          Text('Needs attention: ${runtimeSession.needsAttention ? 'Yes' : 'No'}'),
          if (supportPolicy.exportSnapshotLabel != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              'Last captured export snapshot',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: attentionColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(supportPolicy.exportSnapshotLabel!),
            if (exportCapturedAt != null)
              Text('Captured at: ${exportCapturedAt!.toIso8601String()}'),
            const SizedBox(height: 6),
            Text(supportPolicy.exportSnapshotDetail!),
          ],
          const SizedBox(height: 12),
          Text(
            supportPolicy.currentTruthSubtitle,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(supportPolicy.currentTruthMessage),
          if (supportPolicy.showExitConfirmationWarning) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    supportPolicy.exitConfirmationTitle ??
                        'Exit confirmation pending',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(supportPolicy.exitConfirmationBody!),
                ],
              ),
            ),
          ],
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
                Text(supportPolicy.actionSafety.label),
                const SizedBox(height: 4),
                Text(supportPolicy.actionSafety.detail),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  supportPolicy.primaryOperatorTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(supportPolicy.primaryOperatorBody),
                if (supportPolicy.preferredEvidenceActionLabel != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    'Preferred evidence action: ${supportPolicy.preferredEvidenceActionLabel}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(supportPolicy.postureGuidance),
        ],
      ),
    );
  }
}

class _SupportBundleSummaryCard extends StatelessWidget {
  const _SupportBundleSummaryCard({
    required this.exportBackend,
    required this.runtimePosture,
  });

  final String exportBackend;
  final RuntimePosture runtimePosture;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Before you export a support bundle',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Use this when a connection test fails, the runtime exits unexpectedly, or you want to share a support-ready snapshot.',
          ),
          const SizedBox(height: 12),
          Text(
            'Current evidence grade: ${runtimePosture.evidenceGradeLabel}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(runtimePosture.evidenceGradeNote),
          const SizedBox(height: 12),
          Text(
            runtimePosture.artifactCapabilityLabel,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(runtimePosture.artifactCapabilityNote),
          const SizedBox(height: 12),
          Text(
            runtimePosture.operatorGuidanceHeading,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...runtimePosture.operatorChecklist.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('• $item'),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Includes'),
          const SizedBox(height: 4),
          const Text(
            '• selected profile summary and profile portability bundle\n• controller status, runtime session, and recent events\n• settings and release metadata snapshots\n• last uncaught app error summary (if available)\n• secure-storage backend summary and key inventory',
          ),
          const SizedBox(height: 12),
          const Text('Does not include'),
          const SizedBox(height: 4),
          const Text(
            '• your raw Trojan password\n• arbitrary local files outside the exported JSON bundle',
          ),
          const SizedBox(height: 12),
          Text(
            'Export target uses the current diagnostics backend: $exportBackend',
          ),
        ],
      ),
    );
  }
}
