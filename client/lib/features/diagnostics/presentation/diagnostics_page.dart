import 'package:flutter/material.dart';

import '../../../core/widgets/section_card.dart';
import '../../../platform/services/service_registry.dart';
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
      subtitle: 'Create a support-ready snapshot when something goes wrong. Use this only when you need to share or inspect a failure. Export backend: ${widget.services.diagnosticsFileExporter.backendName}',
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
            onPressed: _preview.startsWith('Press “Generate') || _busy ? null : _export,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (_lastExportTarget != null) ...<Widget>[
            Text('Last export target: $_lastExportTarget'),
            const SizedBox(height: 12),
          ],
          SelectableText(_preview),
        ],
      ),
    );
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
        SnackBar(content: Text('Failed to generate diagnostics preview: $error')),
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
