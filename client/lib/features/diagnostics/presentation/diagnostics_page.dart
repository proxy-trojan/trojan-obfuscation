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
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Diagnostics',
      subtitle: 'Preview what a future export bundle could contain.',
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
          FilledButton.icon(
            onPressed: _busy ? null : _generate,
            icon: const Icon(Icons.download),
            label: const Text('Generate preview'),
          ),
        ],
      ),
      child: SelectableText(_preview),
    );
  }

  Future<void> _generate() async {
    setState(() => _busy = true);
    final preview = await widget.services.diagnostics.buildPreviewBundle();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _preview = preview;
    });
  }
}
