import 'package:flutter/material.dart';

Future<String?> showTrojanPasswordDialog(
  BuildContext context, {
  String title = 'Save Password',
  String helperText = 'Stored separately from the profile so the profile stays portable.',
  String submitLabel = 'Save Password',
}) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext context) => _TrojanPasswordDialog(
      title: title,
      helperText: helperText,
      submitLabel: submitLabel,
    ),
  );
}

Future<void> showTrojanPasswordRevealDialog(
  BuildContext context, {
  required String profileName,
  required String password,
}) {
  var obscureText = true;

  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (BuildContext context, void Function(void Function()) setState) {
          return AlertDialog(
            title: Text('Saved Password · $profileName'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    obscureText ? '•' * password.length : password,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Only reveal this when you need to confirm the saved password.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => setState(() => obscureText = !obscureText),
                child: Text(obscureText ? 'Reveal' : 'Hide'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    },
  );
}

class _TrojanPasswordDialog extends StatefulWidget {
  const _TrojanPasswordDialog({
    required this.title,
    required this.helperText,
    required this.submitLabel,
  });

  final String title;
  final String helperText;
  final String submitLabel;

  @override
  State<_TrojanPasswordDialog> createState() => _TrojanPasswordDialogState();
}

class _TrojanPasswordDialogState extends State<_TrojanPasswordDialog> {
  late final TextEditingController _controller;
  bool _obscureText = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _controller.text.trim().isNotEmpty;

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 520,
        child: TextField(
          controller: _controller,
          autofocus: true,
          obscureText: _obscureText,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Password',
            helperText: widget.helperText,
            hintText: 'Enter password',
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscureText = !_obscureText),
              icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: canSave
              ? () => Navigator.of(context).pop(_controller.text.trim())
              : null,
          child: Text(widget.submitLabel),
        ),
      ],
    );
  }
}
