import 'package:flutter/material.dart';

Future<String?> showImportTextDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext context) => const _ImportTextDialog(),
  );
}

class _ImportTextDialog extends StatefulWidget {
  const _ImportTextDialog();

  @override
  State<_ImportTextDialog> createState() => _ImportTextDialogState();
}

class _ImportTextDialogState extends State<_ImportTextDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import Profile JSON'),
      content: SizedBox(
        width: 560,
        child: TextField(
          controller: _controller,
          minLines: 12,
          maxLines: 18,
          decoration: const InputDecoration(
            hintText: 'Paste exported profile JSON here',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Import'),
        ),
      ],
    );
  }
}

Future<String?> showPathInputDialog(
  BuildContext context, {
  required String title,
  required String hintText,
  String? initialValue,
  String confirmLabel = 'Confirm',
}) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext context) => _PathInputDialog(
      title: title,
      hintText: hintText,
      initialValue: initialValue,
      confirmLabel: confirmLabel,
    ),
  );
}

class _PathInputDialog extends StatefulWidget {
  const _PathInputDialog({
    required this.title,
    required this.hintText,
    this.initialValue,
    required this.confirmLabel,
  });

  final String title;
  final String hintText;
  final String? initialValue;
  final String confirmLabel;

  @override
  State<_PathInputDialog> createState() => _PathInputDialogState();
}

class _PathInputDialogState extends State<_PathInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 560,
        child: TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: widget.hintText,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

Future<void> showExportTextDialog(
  BuildContext context, {
  required String title,
  required String text,
}) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 560,
          child: SelectableText(text),
        ),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}
