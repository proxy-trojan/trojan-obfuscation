import 'package:flutter/material.dart';

import '../../routing/domain/routing_models.dart';
import '../../routing/domain/routing_profile_config.dart';
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
  static const _routingModeDropdownKey = Key('routing-mode-dropdown');
  static const _routingDefaultActionDropdownKey =
      Key('routing-default-action-dropdown');
  static const _routingGlobalActionDropdownKey =
      Key('routing-global-action-dropdown');

  late final TextEditingController _nameController;
  late final TextEditingController _serverHostController;
  late final TextEditingController _serverPortController;
  late final TextEditingController _sniController;
  late final TextEditingController _localSocksPortController;
  late final TextEditingController _notesController;
  bool _verifyTls = true;
  String? _validationError;
  late RoutingMode _routingMode;
  late RoutingAction _routingDefaultAction;
  late RoutingAction _routingGlobalAction;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _serverHostController =
        TextEditingController(text: initial?.serverHost ?? '');
    _serverPortController =
        TextEditingController(text: '${initial?.serverPort ?? 443}');
    _sniController = TextEditingController(text: initial?.sni ?? '');
    _localSocksPortController =
        TextEditingController(text: '${initial?.localSocksPort ?? 1080}');
    _notesController = TextEditingController(text: initial?.notes ?? '');
    _verifyTls = initial?.verifyTls ?? true;
    final initialRouting = initial?.routing ?? RoutingProfileConfig.defaults;
    _routingMode = initialRouting.mode;
    _routingDefaultAction = initialRouting.defaultAction;
    _routingGlobalAction = initialRouting.globalAction;
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
              if (_validationError != null) ...<Widget>[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _validationError!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
                const SizedBox(height: 8),
              ],
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
                decoration:
                    const InputDecoration(labelText: 'Local SOCKS port'),
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
              const SizedBox(height: 8),
              DropdownButtonFormField<RoutingMode>(
                key: _routingModeDropdownKey,
                initialValue: _routingMode,
                decoration: const InputDecoration(labelText: 'Routing mode'),
                items: RoutingMode.values
                    .map(
                      (mode) => DropdownMenuItem<RoutingMode>(
                        value: mode,
                        child: Text(mode.name),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() => _routingMode = value);
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<RoutingAction>(
                key: _routingDefaultActionDropdownKey,
                initialValue: _routingDefaultAction,
                decoration: const InputDecoration(
                  labelText: 'Routing default action',
                ),
                items: RoutingAction.values
                    .map(
                      (action) => DropdownMenuItem<RoutingAction>(
                        value: action,
                        child: Text(action.name),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() => _routingDefaultAction = value);
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<RoutingAction>(
                key: _routingGlobalActionDropdownKey,
                initialValue: _routingGlobalAction,
                decoration: const InputDecoration(
                  labelText: 'Routing global action',
                ),
                items: RoutingAction.values
                    .map(
                      (action) => DropdownMenuItem<RoutingAction>(
                        value: action,
                        child: Text(action.name),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() => _routingGlobalAction = value);
                },
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
    final name = _nameController.text.trim();
    final serverHost = _serverHostController.text.trim();
    final serverPort = int.tryParse(_serverPortController.text.trim());
    final localSocksPort = int.tryParse(_localSocksPortController.text.trim());

    String? validationError;
    if (name.isEmpty) {
      validationError = 'Profile name is required.';
    } else if (serverHost.isEmpty) {
      validationError = 'Server host is required.';
    } else if (RegExp(r'[\s]').hasMatch(serverHost)) {
      validationError = 'Server host must not contain whitespace.';
    } else if (serverPort == null || serverPort < 1 || serverPort > 65535) {
      validationError = 'Server port must be between 1 and 65535.';
    } else if (localSocksPort == null ||
        localSocksPort < 1 ||
        localSocksPort > 65535) {
      validationError = 'Local SOCKS port must be between 1 and 65535.';
    }

    if (validationError != null) {
      setState(() => _validationError = validationError);
      return;
    }

    final initial = widget.initial;
    final profile = ClientProfile(
      id: initial?.id ?? 'profile-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      serverHost: serverHost,
      serverPort: serverPort!,
      sni: _sniController.text.trim().isEmpty
          ? serverHost
          : _sniController.text.trim(),
      localSocksPort: localSocksPort!,
      verifyTls: _verifyTls,
      notes: _notesController.text.trim(),
      updatedAt: DateTime.now(),
      hasStoredPassword: initial?.hasStoredPassword ?? false,
      routing: RoutingProfileConfig(
        mode: _routingMode,
        defaultAction: _routingDefaultAction,
        globalAction: _routingGlobalAction,
        policyGroups: initial?.routing.policyGroups ??
            RoutingProfileConfig.defaults.policyGroups,
        rules: initial?.routing.rules ?? RoutingProfileConfig.defaults.rules,
      ),
    );
    Navigator.of(context).pop(profile);
  }
}
