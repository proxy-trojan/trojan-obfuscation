import 'package:flutter/material.dart';

import '../../../core/widgets/section_card.dart';
import '../../../platform/services/service_registry.dart';
import '../application/support_issue_descriptor.dart';
import '../../profiles/presentation/import_export_dialog.dart';

class DiagnosticsPage extends StatefulWidget {
  const DiagnosticsPage({super.key, required this.services});

  final ClientServiceRegistry services;

  @override
  State<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends State<DiagnosticsPage> {
  String _preview = 'Press “Generate preview” to build a diagnostics payload.';
  String? _lastExportTarget;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Problem Report',
      subtitle:
          'Create a support-ready snapshot when something goes wrong. Use this when you need to inspect a failure or share a support bundle. Export backend: ${widget.services.diagnosticsFileExporter.backendName}',
      trailing: Wrap(
        spacing: 8,
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
                : _export,
            icon: const Icon(Icons.save_alt),
            label: const Text('Export bundle'),
          ),
          FilledButton.icon(
            onPressed: _busy ? null : _generate,
            icon: const Icon(Icons.download),
            label: const Text('Generate preview'),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _SupportBundleSummaryCard(
              exportBackend:
                  widget.services.diagnosticsFileExporter.backendName,
            ),
            const SizedBox(height: 16),
            if (_lastExportTarget != null) ...<Widget>[
              Text('Last export target: $_lastExportTarget'),
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
      if (!mounted) return;
      setState(() {
        _preview = preview;
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

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final result = await widget.services.diagnostics.exportPreviewBundle();
      if (!mounted) return;
      setState(() {
        _preview = result.contents;
        _lastExportTarget = result.target;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export diagnostics bundle: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}

class _SupportBundleSummaryCard extends StatelessWidget {
  const _SupportBundleSummaryCard({required this.exportBackend});

  final String exportBackend;

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
          const Text('Includes'),
          const SizedBox(height: 4),
          const Text(
            '• selected profile summary\n• controller status, session, and recent events\n• settings and packaging/update metadata\n• secure-storage backend summary and key counts',
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
