import 'package:flutter/material.dart';

import '../domain/client_profile.dart';

Future<ClientProfile?> showProfileEditorDialog(
  BuildContext context, {
  ClientProfile? initial,
}) {
  return showDialog<ClientProfile>(
    context: context,
    builder: (BuildContext context) => _ProfileEditorDialog(initial: initial),
  );
}

class _ProfileEditorDialog extends StatefulWidget {
  const _ProfileEditorDialog({this.initial});

  final ClientProfile? initial;

  @override
  State<_ProfileEditorDialog> createState() => _ProfileEditorDialogState();
}

class _ProfileEditorDialogState extends State<_ProfileEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _serverHostController;
  late final TextEditingController _serverPortController;
  late final TextEditingController _sniController;
  late final TextEditingController _localSocksPortController;
  late final TextEditingController _notesController;
  bool _verifyTls = true;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _serverHostController = TextEditingController(text: initial?.serverHost ?? '');
    _serverPortController = TextEditingController(text: '${initial?.serverPort ?? 443}');
    _sniController = TextEditingController(text: initial?.sni ?? '');
    _localSocksPortController = TextEditingController(text: '${initial?.localSocksPort ?? 1080}');
    _notesController = TextEditingController(text: initial?.notes ?? '');
    _verifyTls = initial?.verifyTls ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _serverHostController.dispose();
    _serverPortController.dispose();
    _sniController.dispose();
    _localSocksPortController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initial != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Profile' : 'Create Profile'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Profile name'),
              ),
              TextField(
                controller: _serverHostController,
                decoration: const InputDecoration(labelText: 'Server host'),
              ),
              TextField(
                controller: _serverPortController,
                decoration: const InputDecoration(labelText: 'Server port'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _sniController,
                decoration: const InputDecoration(labelText: 'SNI'),
              ),
              TextField(
                controller: _localSocksPortController,
                decoration: const InputDecoration(labelText: 'Local SOCKS port'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'You will save the password after the profile is created.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _verifyTls,
                onChanged: (bool value) => setState(() => _verifyTls = value),
                title: const Text('Verify TLS'),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }

  void _submit() {
    final initial = widget.initial;
    final profile = ClientProfile(
      id: initial?.id ?? 'profile-${DateTime.now().microsecondsSinceEpoch}',
      name: _nameController.text.trim().isEmpty ? 'Untitled Profile' : _nameController.text.trim(),
      serverHost: _serverHostController.text.trim().isEmpty
          ? 'example.com'
          : _serverHostController.text.trim(),
      serverPort: int.tryParse(_serverPortController.text.trim()) ?? 443,
      sni: _sniController.text.trim().isEmpty ? 'example.com' : _sniController.text.trim(),
      localSocksPort: int.tryParse(_localSocksPortController.text.trim()) ?? 1080,
      verifyTls: _verifyTls,
      notes: _notesController.text.trim(),
      updatedAt: DateTime.now(),
      hasStoredPassword: initial?.hasStoredPassword ?? false,
    );
    Navigator.of(context).pop(profile);
  }
}
