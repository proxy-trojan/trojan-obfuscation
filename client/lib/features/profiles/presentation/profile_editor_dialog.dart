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

enum _RoutingRuleTargetType {
  direct,
  policyGroup,
}

class _PolicyGroupDraft {
  const _PolicyGroupDraft({
    required this.id,
    required this.name,
    required this.action,
  });

  final String id;
  final String name;
  final RoutingAction action;
}

class _RoutingRuleDraft {
  const _RoutingRuleDraft({
    required this.id,
    required this.name,
    required this.priority,
    required this.domainKeyword,
    required this.targetType,
    this.directAction,
    this.policyGroupId,
  });

  final String id;
  final String name;
  final int priority;
  final String domainKeyword;
  final _RoutingRuleTargetType targetType;
  final RoutingAction? directAction;
  final String? policyGroupId;
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
  static const _addPolicyGroupButtonKey = Key('add-policy-group-button');
  static const _addRoutingRuleButtonKey = Key('add-routing-rule-button');

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
  late List<RoutingPolicyGroup> _routingPolicyGroups;
  late List<RoutingRule> _routingRules;

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
    _routingPolicyGroups = List<RoutingPolicyGroup>.from(
      initialRouting.policyGroups,
    );
    _routingRules = List<RoutingRule>.from(initialRouting.rules);
    _sortRoutingCollections();
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
        width: 560,
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
              const SizedBox(height: 16),
              _sectionHeader(
                context,
                title: 'Routing policy groups',
                addButtonKey: _addPolicyGroupButtonKey,
                onAddPressed: _onAddPolicyGroupPressed,
              ),
              if (_routingPolicyGroups.isEmpty)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('No policy groups'),
                )
              else
                ..._routingPolicyGroups.map(_buildPolicyGroupRow),
              const SizedBox(height: 12),
              _sectionHeader(
                context,
                title: 'Routing rules',
                addButtonKey: _addRoutingRuleButtonKey,
                onAddPressed: _onAddRoutingRulePressed,
              ),
              if (_routingRules.isEmpty)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('No routing rules'),
                )
              else
                ..._routingRules.map(_buildRoutingRuleRow),
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

  Widget _sectionHeader(
    BuildContext context, {
    required String title,
    required Key addButtonKey,
    required VoidCallback onAddPressed,
  }) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        TextButton.icon(
          key: addButtonKey,
          onPressed: onAddPressed,
          icon: const Icon(Icons.add),
          label: const Text('Add'),
        ),
      ],
    );
  }

  Widget _buildPolicyGroupRow(RoutingPolicyGroup group) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        dense: true,
        title: Text('${group.id} · ${group.name}'),
        subtitle: Text('action: ${group.action.name}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              key: Key('edit-policy-group-${group.id}'),
              tooltip: 'Edit policy group',
              onPressed: () => _onEditPolicyGroupPressed(group),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              key: Key('remove-policy-group-${group.id}'),
              tooltip: 'Remove policy group',
              onPressed: () => _removePolicyGroup(group.id),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutingRuleRow(RoutingRule rule) {
    final actionSummary = rule.action.usesPolicyGroup
        ? 'policy-group:${rule.action.policyGroupId}'
        : 'direct:${(rule.action.directAction ?? _routingDefaultAction).name}';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        dense: true,
        title: Text('${rule.id} · ${rule.name}'),
        subtitle: Text(
          'priority: ${rule.priority} · $actionSummary · match.keyword: ${rule.match.domainKeyword ?? '-'}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              key: Key('edit-routing-rule-${rule.id}'),
              tooltip: 'Edit routing rule',
              onPressed: () => _onEditRoutingRulePressed(rule),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              key: Key('remove-routing-rule-${rule.id}'),
              tooltip: 'Remove routing rule',
              onPressed: () => _removeRoutingRule(rule.id),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onAddPolicyGroupPressed() async {
    final result = await showDialog<_PolicyGroupDraft>(
      context: context,
      builder: (context) => const _PolicyGroupEditorDialog(),
    );
    if (result == null) {
      return;
    }
    _upsertPolicyGroup(result);
  }

  Future<void> _onEditPolicyGroupPressed(RoutingPolicyGroup current) async {
    final result = await showDialog<_PolicyGroupDraft>(
      context: context,
      builder: (context) => _PolicyGroupEditorDialog(initial: current),
    );
    if (result == null) {
      return;
    }
    _upsertPolicyGroup(result);
  }

  void _upsertPolicyGroup(_PolicyGroupDraft draft) {
    setState(() {
      final next = RoutingPolicyGroup(
        id: draft.id,
        name: draft.name,
        action: draft.action,
      );
      final index = _routingPolicyGroups.indexWhere((g) => g.id == draft.id);
      if (index >= 0) {
        _routingPolicyGroups[index] = next;
      } else {
        _routingPolicyGroups.add(next);
      }
      _sortRoutingCollections();
    });
  }

  Future<void> _onAddRoutingRulePressed() async {
    final result = await showDialog<_RoutingRuleDraft>(
      context: context,
      builder: (context) => _RoutingRuleEditorDialog(
        policyGroups: _routingPolicyGroups,
        defaultAction: _routingDefaultAction,
      ),
    );
    if (result == null) {
      return;
    }
    _upsertRoutingRule(result);
  }

  Future<void> _onEditRoutingRulePressed(RoutingRule current) async {
    final result = await showDialog<_RoutingRuleDraft>(
      context: context,
      builder: (context) => _RoutingRuleEditorDialog(
        policyGroups: _routingPolicyGroups,
        defaultAction: _routingDefaultAction,
        initial: current,
      ),
    );
    if (result == null) {
      return;
    }
    _upsertRoutingRule(result);
  }

  void _upsertRoutingRule(_RoutingRuleDraft draft) {
    final action = draft.targetType == _RoutingRuleTargetType.policyGroup
        ? RoutingRuleAction.policyGroup(draft.policyGroupId)
        : RoutingRuleAction.direct(
            draft.directAction ?? _routingDefaultAction,
          );

    final nextRule = RoutingRule(
      id: draft.id,
      name: draft.name,
      enabled: true,
      priority: draft.priority,
      match: RoutingRuleMatch(domainKeyword: draft.domainKeyword),
      action: action,
    );

    setState(() {
      final index = _routingRules.indexWhere((r) => r.id == draft.id);
      if (index >= 0) {
        _routingRules[index] = nextRule;
      } else {
        _routingRules.add(nextRule);
      }
      _sortRoutingCollections();
    });
  }

  void _removePolicyGroup(String id) {
    setState(() {
      _routingPolicyGroups = _routingPolicyGroups
          .where((group) => group.id != id)
          .toList(growable: false);
      _routingRules = _routingRules.map((rule) {
        if (rule.action.policyGroupId != id) {
          return rule;
        }
        return _copyRoutingRuleWithAction(
          rule,
          RoutingRuleAction.direct(_routingDefaultAction),
        );
      }).toList(growable: false);
      _sortRoutingCollections();
    });
  }

  void _removeRoutingRule(String id) {
    setState(() {
      _routingRules =
          _routingRules.where((rule) => rule.id != id).toList(growable: false);
      _sortRoutingCollections();
    });
  }

  void _sortRoutingCollections() {
    _routingPolicyGroups.sort((a, b) => a.id.compareTo(b.id));
    _routingRules.sort((a, b) {
      final byPriority = a.priority.compareTo(b.priority);
      if (byPriority != 0) {
        return byPriority;
      }
      return a.id.compareTo(b.id);
    });
  }

  RoutingRule _copyRoutingRuleWithAction(
    RoutingRule source,
    RoutingRuleAction action,
  ) {
    return RoutingRule(
      id: source.id,
      name: source.name,
      enabled: source.enabled,
      priority: source.priority,
      match: source.match,
      action: action,
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

    final policyGroupIds = _routingPolicyGroups.map((g) => g.id).toSet();
    final normalizedRules = _routingRules.map((rule) {
      if (rule.action.usesPolicyGroup &&
          !policyGroupIds.contains(rule.action.policyGroupId)) {
        return _copyRoutingRuleWithAction(
          rule,
          RoutingRuleAction.direct(_routingDefaultAction),
        );
      }
      return rule;
    }).toList(growable: false);

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
        policyGroups:
            List<RoutingPolicyGroup>.unmodifiable(_routingPolicyGroups),
        rules: List<RoutingRule>.unmodifiable(normalizedRules),
      ),
    );
    Navigator.of(context).pop(profile);
  }
}

class _PolicyGroupEditorDialog extends StatefulWidget {
  const _PolicyGroupEditorDialog({this.initial});

  final RoutingPolicyGroup? initial;

  @override
  State<_PolicyGroupEditorDialog> createState() =>
      _PolicyGroupEditorDialogState();
}

class _PolicyGroupEditorDialogState extends State<_PolicyGroupEditorDialog> {
  static const _idFieldKey = Key('policy-group-id-field');
  static const _nameFieldKey = Key('policy-group-name-field');
  static const _actionDropdownKey = Key('policy-group-action-dropdown');
  static const _saveButtonKey = Key('save-policy-group-button');

  late final TextEditingController _idController;
  late final TextEditingController _nameController;
  RoutingAction _action = RoutingAction.proxy;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _idController = TextEditingController(text: initial?.id ?? '');
    _nameController = TextEditingController(text: initial?.name ?? '');
    _action = initial?.action ?? RoutingAction.proxy;
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          widget.initial == null ? 'Add policy group' : 'Edit policy group'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (_validationError != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _validationError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            TextField(
              key: _idFieldKey,
              controller: _idController,
              enabled: widget.initial == null,
              decoration: const InputDecoration(labelText: 'Policy group id'),
            ),
            TextField(
              key: _nameFieldKey,
              controller: _nameController,
              decoration:
                  const InputDecoration(labelText: 'Policy group display name'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<RoutingAction>(
              key: _actionDropdownKey,
              initialValue: _action,
              decoration:
                  const InputDecoration(labelText: 'Policy group action'),
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
                setState(() => _action = value);
              },
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: _saveButtonKey,
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _submit() {
    final id = _idController.text.trim();
    final name = _nameController.text.trim();

    if (id.isEmpty) {
      setState(() => _validationError = 'Policy group id is required.');
      return;
    }

    if (RegExp(r'[\s]').hasMatch(id)) {
      setState(() =>
          _validationError = 'Policy group id must not contain whitespace.');
      return;
    }

    Navigator.of(context).pop(
      _PolicyGroupDraft(
        id: id,
        name: name.isEmpty ? id : name,
        action: _action,
      ),
    );
  }
}

class _RoutingRuleEditorDialog extends StatefulWidget {
  const _RoutingRuleEditorDialog({
    required this.policyGroups,
    required this.defaultAction,
    this.initial,
  });

  final List<RoutingPolicyGroup> policyGroups;
  final RoutingAction defaultAction;
  final RoutingRule? initial;

  @override
  State<_RoutingRuleEditorDialog> createState() =>
      _RoutingRuleEditorDialogState();
}

class _RoutingRuleEditorDialogState extends State<_RoutingRuleEditorDialog> {
  static const _idFieldKey = Key('routing-rule-id-field');
  static const _nameFieldKey = Key('routing-rule-name-field');
  static const _priorityFieldKey = Key('routing-rule-priority-field');
  static const _domainKeywordFieldKey =
      Key('routing-rule-domain-keyword-field');
  static const _targetTypeDropdownKey =
      Key('routing-rule-target-type-dropdown');
  static const _directActionDropdownKey =
      Key('routing-rule-direct-action-dropdown');
  static const _policyGroupDropdownKey =
      Key('routing-rule-policy-group-dropdown');
  static const _saveButtonKey = Key('save-routing-rule-button');

  late final TextEditingController _idController;
  late final TextEditingController _nameController;
  late final TextEditingController _priorityController;
  late final TextEditingController _domainKeywordController;
  _RoutingRuleTargetType _targetType = _RoutingRuleTargetType.direct;
  late RoutingAction _directAction;
  String? _policyGroupId;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _idController = TextEditingController(text: initial?.id ?? '');
    _nameController = TextEditingController(text: initial?.name ?? '');
    _priorityController = TextEditingController(
      text: '${initial?.priority ?? 100}',
    );
    _domainKeywordController = TextEditingController(
      text: initial?.match.domainKeyword ?? '',
    );

    if (initial == null) {
      _targetType = _RoutingRuleTargetType.direct;
      _directAction = widget.defaultAction;
      if (widget.policyGroups.isNotEmpty) {
        _policyGroupId = widget.policyGroups.first.id;
      }
      return;
    }

    _targetType = initial.action.usesPolicyGroup
        ? _RoutingRuleTargetType.policyGroup
        : _RoutingRuleTargetType.direct;
    _directAction = initial.action.directAction ?? widget.defaultAction;
    _policyGroupId = initial.action.policyGroupId;
    if (_policyGroupId == null && widget.policyGroups.isNotEmpty) {
      _policyGroupId = widget.policyGroups.first.id;
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _priorityController.dispose();
    _domainKeywordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          widget.initial == null ? 'Add routing rule' : 'Edit routing rule'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (_validationError != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _validationError!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              TextField(
                key: _idFieldKey,
                controller: _idController,
                enabled: widget.initial == null,
                decoration: const InputDecoration(labelText: 'Rule id'),
              ),
              TextField(
                key: _nameFieldKey,
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Rule name'),
              ),
              TextField(
                key: _priorityFieldKey,
                controller: _priorityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Priority'),
              ),
              TextField(
                key: _domainKeywordFieldKey,
                controller: _domainKeywordController,
                decoration:
                    const InputDecoration(labelText: 'Domain keyword match'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<_RoutingRuleTargetType>(
                key: _targetTypeDropdownKey,
                initialValue: _targetType,
                decoration:
                    const InputDecoration(labelText: 'Rule action target'),
                items: const <DropdownMenuItem<_RoutingRuleTargetType>>[
                  DropdownMenuItem<_RoutingRuleTargetType>(
                    value: _RoutingRuleTargetType.direct,
                    child: Text('direct'),
                  ),
                  DropdownMenuItem<_RoutingRuleTargetType>(
                    value: _RoutingRuleTargetType.policyGroup,
                    child: Text('policy-group'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() => _targetType = value);
                },
              ),
              const SizedBox(height: 8),
              if (_targetType == _RoutingRuleTargetType.direct)
                DropdownButtonFormField<RoutingAction>(
                  key: _directActionDropdownKey,
                  initialValue: _directAction,
                  decoration: const InputDecoration(labelText: 'Direct action'),
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
                    setState(() => _directAction = value);
                  },
                )
              else
                DropdownButtonFormField<String>(
                  key: _policyGroupDropdownKey,
                  initialValue: _policyGroupId,
                  decoration:
                      const InputDecoration(labelText: 'Policy group target'),
                  items: widget.policyGroups
                      .map(
                        (group) => DropdownMenuItem<String>(
                          value: group.id,
                          child: Text(group.id),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() => _policyGroupId = value);
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
          key: _saveButtonKey,
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _submit() {
    final id = _idController.text.trim();
    final name = _nameController.text.trim();
    final priority = int.tryParse(_priorityController.text.trim());
    final domainKeyword = _domainKeywordController.text.trim();

    if (id.isEmpty) {
      setState(() => _validationError = 'Rule id is required.');
      return;
    }
    if (RegExp(r'[\s]').hasMatch(id)) {
      setState(() => _validationError = 'Rule id must not contain whitespace.');
      return;
    }
    if (priority == null) {
      setState(() => _validationError = 'Priority must be a valid integer.');
      return;
    }
    if (domainKeyword.isEmpty) {
      setState(() => _validationError = 'Domain keyword match is required.');
      return;
    }

    if (_targetType == _RoutingRuleTargetType.policyGroup) {
      if (widget.policyGroups.isEmpty) {
        setState(() => _validationError =
            'Add at least one policy group before using policy-group action.');
        return;
      }
      if (_policyGroupId == null || _policyGroupId!.trim().isEmpty) {
        setState(() => _validationError = 'Policy group target is required.');
        return;
      }
    }

    Navigator.of(context).pop(
      _RoutingRuleDraft(
        id: id,
        name: name.isEmpty ? id : name,
        priority: priority,
        domainKeyword: domainKeyword,
        targetType: _targetType,
        directAction:
            _targetType == _RoutingRuleTargetType.direct ? _directAction : null,
        policyGroupId: _targetType == _RoutingRuleTargetType.policyGroup
            ? _policyGroupId
            : null,
      ),
    );
  }
}
