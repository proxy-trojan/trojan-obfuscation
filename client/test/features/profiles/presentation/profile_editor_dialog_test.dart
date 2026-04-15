import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/profiles/domain/client_profile.dart';
import 'package:trojan_pro_client/features/profiles/presentation/profile_editor_dialog.dart';
import 'package:trojan_pro_client/features/routing/domain/routing_models.dart';
import 'package:trojan_pro_client/features/routing/domain/routing_profile_config.dart';

Future<void> _selectDropdownValue(
  WidgetTester tester, {
  required Key dropdownKey,
  required String valueText,
}) async {
  final dropdown = find.byKey(dropdownKey);
  await tester.ensureVisible(dropdown);
  await tester.pumpAndSettle();

  Future<bool> openMenuAndCheckOption() async {
    await tester.tap(dropdown, warnIfMissed: false);
    await tester.pumpAndSettle();
    return find.text(valueText).evaluate().isNotEmpty;
  }

  var optionFound = await openMenuAndCheckOption();
  if (!optionFound) {
    await tester.ensureVisible(dropdown);
    await tester.pumpAndSettle();
    optionFound = await openMenuAndCheckOption();
  }

  expect(find.text(valueText), findsWidgets);
  final option = find.text(valueText).last;
  await tester.ensureVisible(option);
  await tester.pumpAndSettle();
  await tester.tap(option, warnIfMissed: false);
  await tester.pumpAndSettle();
}

Future<void> _selectRoutingMode(WidgetTester tester, RoutingMode mode) {
  return _selectDropdownValue(
    tester,
    dropdownKey: const Key('routing-mode-dropdown'),
    valueText: mode.name,
  );
}

Future<void> _selectRoutingDefaultAction(
  WidgetTester tester,
  RoutingAction action,
) {
  return _selectDropdownValue(
    tester,
    dropdownKey: const Key('routing-default-action-dropdown'),
    valueText: action.name,
  );
}

Future<void> _selectRoutingGlobalAction(
  WidgetTester tester,
  RoutingAction action,
) {
  return _selectDropdownValue(
    tester,
    dropdownKey: const Key('routing-global-action-dropdown'),
    valueText: action.name,
  );
}

Future<void> _addPolicyGroup(
  WidgetTester tester, {
  required String id,
  required String name,
  required RoutingAction action,
}) async {
  final addButton = find.byKey(const Key('add-policy-group-button'));
  await tester.ensureVisible(addButton);
  await tester.pumpAndSettle();
  await tester.tap(addButton);
  await tester.pumpAndSettle();

  await tester.enterText(find.byKey(const Key('policy-group-id-field')), id);
  await tester.enterText(
      find.byKey(const Key('policy-group-name-field')), name);
  await _selectDropdownValue(
    tester,
    dropdownKey: const Key('policy-group-action-dropdown'),
    valueText: action.name,
  );

  await tester.tap(find.byKey(const Key('save-policy-group-button')));
  await tester.pumpAndSettle();
}

Future<void> _addRoutingRule(
  WidgetTester tester, {
  required String id,
  required String name,
  required int priority,
  required String domainKeyword,
  bool usePolicyGroup = false,
  RoutingAction directAction = RoutingAction.proxy,
  String? policyGroupId,
}) async {
  final addButton = find.byKey(const Key('add-routing-rule-button'));
  await tester.ensureVisible(addButton);
  await tester.pumpAndSettle();
  await tester.tap(addButton);
  await tester.pumpAndSettle();

  await tester.enterText(find.byKey(const Key('routing-rule-id-field')), id);
  await tester.enterText(
      find.byKey(const Key('routing-rule-name-field')), name);
  await tester.enterText(
      find.byKey(const Key('routing-rule-priority-field')), '$priority');
  await tester.enterText(
    find.byKey(const Key('routing-rule-domain-keyword-field')),
    domainKeyword,
  );

  if (usePolicyGroup) {
    await _selectDropdownValue(
      tester,
      dropdownKey: const Key('routing-rule-target-type-dropdown'),
      valueText: 'policy-group',
    );
    await _selectDropdownValue(
      tester,
      dropdownKey: const Key('routing-rule-policy-group-dropdown'),
      valueText: policyGroupId!,
    );
  } else {
    await _selectDropdownValue(
      tester,
      dropdownKey: const Key('routing-rule-direct-action-dropdown'),
      valueText: directAction.name,
    );
  }

  await tester.tap(find.byKey(const Key('save-routing-rule-button')));
  await tester.pumpAndSettle();
}

Future<Completer<ClientProfile?>> _openEditorDialog(
  WidgetTester tester, {
  ClientProfile? initial,
}) async {
  final resultCompleter = Completer<ClientProfile?>();

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) {
            return FilledButton(
              onPressed: () {
                showProfileEditorDialog(
                  context,
                  initial: initial,
                ).then(resultCompleter.complete);
              },
              child: const Text('Open Editor'),
            );
          },
        ),
      ),
    ),
  );

  await tester.tap(find.text('Open Editor'));
  await tester.pumpAndSettle();
  return resultCompleter;
}

void main() {
  testWidgets('shows validation error when profile name is empty',
      (WidgetTester tester) async {
    final completer = await _openEditorDialog(tester);

    // Keep host/ports valid so we isolate name validation.
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(1), 'example.com');
    await tester.enterText(fields.at(2), '443');
    await tester.enterText(fields.at(4), '1080');

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Profile name is required.'), findsOneWidget);
    expect(completer.isCompleted, isFalse);
  });

  testWidgets('shows validation error when server port is out of range',
      (WidgetTester tester) async {
    final completer = await _openEditorDialog(tester);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Node A');
    await tester.enterText(fields.at(1), 'example.com');
    await tester.enterText(fields.at(2), '70000');
    await tester.enterText(fields.at(4), '1080');

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(
        find.text('Server port must be between 1 and 65535.'), findsOneWidget);
    expect(completer.isCompleted, isFalse);
  });

  testWidgets('submits valid profile and defaults empty SNI to server host',
      (WidgetTester tester) async {
    final completer = await _openEditorDialog(tester);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Prod HK');
    await tester.enterText(fields.at(1), 'prod.example.com');
    await tester.enterText(fields.at(2), '443');
    await tester.enterText(fields.at(3), '');
    await tester.enterText(fields.at(4), '2080');
    await tester.enterText(fields.at(5), 'primary edge');

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(completer.isCompleted, isTrue);
    final profile = await completer.future;
    expect(profile, isNotNull);
    expect(profile!.name, 'Prod HK');
    expect(profile.serverHost, 'prod.example.com');
    expect(profile.serverPort, 443);
    expect(profile.sni, 'prod.example.com');
    expect(profile.localSocksPort, 2080);
    expect(profile.notes, 'primary edge');
  });

  testWidgets('submits selected routing defaults for new profile',
      (WidgetTester tester) async {
    final completer = await _openEditorDialog(tester);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'JP Edge');
    await tester.enterText(fields.at(1), 'jp.edge.example.com');
    await tester.enterText(fields.at(2), '443');
    await tester.enterText(fields.at(4), '1080');

    await _selectRoutingMode(tester, RoutingMode.global);
    await _selectRoutingDefaultAction(tester, RoutingAction.direct);
    await _selectRoutingGlobalAction(tester, RoutingAction.block);

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(completer.isCompleted, isTrue);
    final profile = await completer.future;
    expect(profile, isNotNull);
    expect(profile!.routing.mode, RoutingMode.global);
    expect(profile.routing.defaultAction, RoutingAction.direct);
    expect(profile.routing.globalAction, RoutingAction.block);
  });

  testWidgets('editing profile keeps existing routing configuration',
      (WidgetTester tester) async {
    const routing = RoutingProfileConfig(
      mode: RoutingMode.global,
      defaultAction: RoutingAction.direct,
      globalAction: RoutingAction.block,
      policyGroups: <RoutingPolicyGroup>[],
      rules: <RoutingRule>[],
    );
    final initial = ClientProfile(
      id: 'profile-hk-1',
      name: 'HK Edge',
      serverHost: 'hk.edge.example.com',
      serverPort: 443,
      sni: 'hk.edge.example.com',
      localSocksPort: 1080,
      verifyTls: true,
      updatedAt: DateTime.parse('2026-04-15T00:00:00.000Z'),
      hasStoredPassword: true,
      routing: routing,
    );
    final completer = await _openEditorDialog(tester, initial: initial);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(completer.isCompleted, isTrue);
    final profile = await completer.future;
    expect(profile, isNotNull);
    expect(profile!.routing, routing);
  });

  testWidgets(
      'editing profile updates only routing mode/default/global and keeps rule payload',
      (WidgetTester tester) async {
    const originalRule = RoutingRule(
      id: 'rule-1',
      name: 'Block social',
      enabled: true,
      priority: 10,
      match: RoutingRuleMatch(domainKeyword: 'social'),
      action: RoutingRuleAction.direct(RoutingAction.block),
    );
    const originalPolicyGroup = RoutingPolicyGroup(
      id: 'group-proxy',
      name: 'Proxy Group',
      action: RoutingAction.proxy,
    );
    const originalRouting = RoutingProfileConfig(
      mode: RoutingMode.rule,
      defaultAction: RoutingAction.proxy,
      globalAction: RoutingAction.proxy,
      policyGroups: <RoutingPolicyGroup>[originalPolicyGroup],
      rules: <RoutingRule>[originalRule],
    );
    final initial = ClientProfile(
      id: 'profile-jp-1',
      name: 'JP Edge',
      serverHost: 'jp.edge.example.com',
      serverPort: 443,
      sni: 'jp.edge.example.com',
      localSocksPort: 1080,
      verifyTls: true,
      updatedAt: DateTime.parse('2026-04-15T00:00:00.000Z'),
      hasStoredPassword: true,
      routing: originalRouting,
    );

    final completer = await _openEditorDialog(tester, initial: initial);

    await _selectRoutingMode(tester, RoutingMode.global);
    await _selectRoutingDefaultAction(tester, RoutingAction.direct);
    await _selectRoutingGlobalAction(tester, RoutingAction.block);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(completer.isCompleted, isTrue);
    final profile = await completer.future;
    expect(profile, isNotNull);
    expect(profile!.routing.mode, RoutingMode.global);
    expect(profile.routing.defaultAction, RoutingAction.direct);
    expect(profile.routing.globalAction, RoutingAction.block);
    expect(profile.routing.rules, originalRouting.rules);
    expect(profile.routing.policyGroups, originalRouting.policyGroups);
  });

  testWidgets('submits profile with added policy group and routing rule',
      (WidgetTester tester) async {
    final completer = await _openEditorDialog(tester);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'SG Edge');
    await tester.enterText(fields.at(1), 'sg.edge.example.com');
    await tester.enterText(fields.at(2), '443');
    await tester.enterText(fields.at(4), '1080');

    await _addPolicyGroup(
      tester,
      id: 'group-proxy',
      name: 'Proxy Group',
      action: RoutingAction.proxy,
    );
    await _addRoutingRule(
      tester,
      id: 'rule-social',
      name: 'Route social domains',
      priority: 10,
      domainKeyword: 'social',
      usePolicyGroup: true,
      policyGroupId: 'group-proxy',
    );

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(completer.isCompleted, isTrue);
    final profile = await completer.future;
    expect(profile, isNotNull);
    expect(profile!.routing.policyGroups.length, 1);
    expect(profile.routing.policyGroups.single.id, 'group-proxy');
    expect(profile.routing.rules.length, 1);
    expect(profile.routing.rules.single.id, 'rule-social');
    expect(profile.routing.rules.single.match.domainKeyword, 'social');
    expect(profile.routing.rules.single.action.policyGroupId, 'group-proxy');
  });

  testWidgets('editing profile can update existing policy group fields',
      (WidgetTester tester) async {
    const originalPolicyGroup = RoutingPolicyGroup(
      id: 'group-edit',
      name: 'Before Edit',
      action: RoutingAction.proxy,
    );
    const originalRouting = RoutingProfileConfig(
      mode: RoutingMode.rule,
      defaultAction: RoutingAction.proxy,
      globalAction: RoutingAction.proxy,
      policyGroups: <RoutingPolicyGroup>[originalPolicyGroup],
      rules: <RoutingRule>[],
    );
    final initial = ClientProfile(
      id: 'profile-edit-group',
      name: 'Edit Group Case',
      serverHost: 'edit-group.example.com',
      serverPort: 443,
      sni: 'edit-group.example.com',
      localSocksPort: 1080,
      verifyTls: true,
      updatedAt: DateTime.parse('2026-04-15T00:00:00.000Z'),
      hasStoredPassword: true,
      routing: originalRouting,
    );

    final completer = await _openEditorDialog(tester, initial: initial);

    final editGroupButton =
        find.byKey(const Key('edit-policy-group-group-edit'));
    await tester.ensureVisible(editGroupButton);
    await tester.pumpAndSettle();
    await tester.tap(editGroupButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('policy-group-name-field')), 'After Edit');
    await _selectDropdownValue(
      tester,
      dropdownKey: const Key('policy-group-action-dropdown'),
      valueText: RoutingAction.direct.name,
    );
    await tester.tap(find.byKey(const Key('save-policy-group-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(completer.isCompleted, isTrue);
    final profile = await completer.future;
    expect(profile, isNotNull);
    expect(profile!.routing.policyGroups, hasLength(1));
    expect(profile.routing.policyGroups.single.id, 'group-edit');
    expect(profile.routing.policyGroups.single.name, 'After Edit');
    expect(profile.routing.policyGroups.single.action, RoutingAction.direct);
  });

  testWidgets('editing profile can update existing routing rule fields',
      (WidgetTester tester) async {
    const originalRule = RoutingRule(
      id: 'rule-edit',
      name: 'Before Rule Edit',
      enabled: true,
      priority: 20,
      match: RoutingRuleMatch(domainKeyword: 'before-keyword'),
      action: RoutingRuleAction.direct(RoutingAction.proxy),
    );
    const originalRouting = RoutingProfileConfig(
      mode: RoutingMode.rule,
      defaultAction: RoutingAction.proxy,
      globalAction: RoutingAction.proxy,
      policyGroups: <RoutingPolicyGroup>[],
      rules: <RoutingRule>[originalRule],
    );
    final initial = ClientProfile(
      id: 'profile-edit-rule',
      name: 'Edit Rule Case',
      serverHost: 'edit-rule.example.com',
      serverPort: 443,
      sni: 'edit-rule.example.com',
      localSocksPort: 1080,
      verifyTls: true,
      updatedAt: DateTime.parse('2026-04-15T00:00:00.000Z'),
      hasStoredPassword: true,
      routing: originalRouting,
    );

    final completer = await _openEditorDialog(tester, initial: initial);

    final editRuleButton = find.byKey(const Key('edit-routing-rule-rule-edit'));
    await tester.ensureVisible(editRuleButton);
    await tester.pumpAndSettle();
    await tester.tap(editRuleButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('routing-rule-name-field')), 'After Rule Edit');
    await tester.enterText(
        find.byKey(const Key('routing-rule-priority-field')), '5');
    await tester.enterText(
      find.byKey(const Key('routing-rule-domain-keyword-field')),
      'after-keyword',
    );
    await tester.enterText(
      find.byKey(const Key('routing-rule-domain-exact-field')),
      'api.example.com',
    );
    await tester.enterText(
      find.byKey(const Key('routing-rule-domain-suffix-field')),
      '.example.com',
    );
    await tester.enterText(
      find.byKey(const Key('routing-rule-domain-regex-field')),
      '^api\\.example\\.com\$',
    );
    await tester.enterText(
      find.byKey(const Key('routing-rule-ip-cidr-field')),
      '10.0.0.0/8',
    );
    await tester.enterText(
      find.byKey(const Key('routing-rule-port-field')),
      '443',
    );
    await tester.enterText(
      find.byKey(const Key('routing-rule-protocol-field')),
      'tcp',
    );
    await tester.enterText(
      find.byKey(const Key('routing-rule-process-name-field')),
      'curl',
    );
    await tester.enterText(
      find.byKey(const Key('routing-rule-process-path-field')),
      '/usr/bin/curl',
    );
    await _selectDropdownValue(
      tester,
      dropdownKey: const Key('routing-rule-direct-action-dropdown'),
      valueText: RoutingAction.block.name,
    );
    await tester.tap(find.byKey(const Key('save-routing-rule-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(completer.isCompleted, isTrue);
    final profile = await completer.future;
    expect(profile, isNotNull);
    expect(profile!.routing.rules, hasLength(1));
    final rule = profile.routing.rules.single;
    expect(rule.id, 'rule-edit');
    expect(rule.name, 'After Rule Edit');
    expect(rule.priority, 5);
    expect(rule.match.domainKeyword, 'after-keyword');
    expect(rule.match.domainExact, 'api.example.com');
    expect(rule.match.domainSuffix, '.example.com');
    expect(rule.match.domainRegex, '^api\\.example\\.com\$');
    expect(rule.match.ipCidr, '10.0.0.0/8');
    expect(rule.match.port, 443);
    expect(rule.match.protocol, 'tcp');
    expect(rule.match.processName, 'curl');
    expect(rule.match.processPath, '/usr/bin/curl');
    expect(rule.action.directAction, RoutingAction.block);
  });

  testWidgets('rule dialog rejects save when no match field is provided',
      (WidgetTester tester) async {
    final completer = await _openEditorDialog(tester);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'No Match Edge');
    await tester.enterText(fields.at(1), 'no-match.example.com');
    await tester.enterText(fields.at(2), '443');
    await tester.enterText(fields.at(4), '1080');

    final addRuleButton = find.byKey(const Key('add-routing-rule-button'));
    await tester.ensureVisible(addRuleButton);
    await tester.pumpAndSettle();
    await tester.tap(addRuleButton);
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('routing-rule-id-field')), 'rule-empty-match');
    await tester.enterText(
        find.byKey(const Key('routing-rule-name-field')), 'Empty Match');
    await tester.enterText(
        find.byKey(const Key('routing-rule-priority-field')), '10');

    await tester.tap(find.byKey(const Key('save-routing-rule-button')));
    await tester.pumpAndSettle();

    expect(
      find.text('At least one match condition is required.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(completer.isCompleted, isTrue);
    final profile = await completer.future;
    expect(profile, isNotNull);
    expect(profile!.routing.rules, isEmpty);
  });

  testWidgets('rule dialog rejects invalid port value',
      (WidgetTester tester) async {
    final completer = await _openEditorDialog(tester);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Invalid Port Edge');
    await tester.enterText(fields.at(1), 'invalid-port.example.com');
    await tester.enterText(fields.at(2), '443');
    await tester.enterText(fields.at(4), '1080');

    final addRuleButton = find.byKey(const Key('add-routing-rule-button'));
    await tester.ensureVisible(addRuleButton);
    await tester.pumpAndSettle();
    await tester.tap(addRuleButton);
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('routing-rule-id-field')), 'rule-invalid-port');
    await tester.enterText(
        find.byKey(const Key('routing-rule-name-field')), 'Invalid Port');
    await tester.enterText(
        find.byKey(const Key('routing-rule-priority-field')), '10');
    await tester.enterText(
      find.byKey(const Key('routing-rule-domain-keyword-field')),
      'keyword',
    );
    await tester.enterText(
      find.byKey(const Key('routing-rule-port-field')),
      '70000',
    );

    await tester.tap(find.byKey(const Key('save-routing-rule-button')));
    await tester.pumpAndSettle();

    expect(
      find.text('Port must be between 1 and 65535.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(completer.isCompleted, isTrue);
    final profile = await completer.future;
    expect(profile, isNotNull);
    expect(profile!.routing.rules, isEmpty);
  });

  testWidgets('editing profile can remove policy group and routing rule',
      (WidgetTester tester) async {
    const originalRule = RoutingRule(
      id: 'rule-remove',
      name: 'Remove me',
      enabled: true,
      priority: 10,
      match: RoutingRuleMatch(domainKeyword: 'remove-me'),
      action: RoutingRuleAction.direct(RoutingAction.block),
    );
    const originalPolicyGroup = RoutingPolicyGroup(
      id: 'group-remove',
      name: 'Remove Group',
      action: RoutingAction.proxy,
    );
    const originalRouting = RoutingProfileConfig(
      mode: RoutingMode.rule,
      defaultAction: RoutingAction.proxy,
      globalAction: RoutingAction.proxy,
      policyGroups: <RoutingPolicyGroup>[originalPolicyGroup],
      rules: <RoutingRule>[originalRule],
    );
    final initial = ClientProfile(
      id: 'profile-remove-1',
      name: 'Remove Case',
      serverHost: 'remove.example.com',
      serverPort: 443,
      sni: 'remove.example.com',
      localSocksPort: 1080,
      verifyTls: true,
      updatedAt: DateTime.parse('2026-04-15T00:00:00.000Z'),
      hasStoredPassword: true,
      routing: originalRouting,
    );

    final completer = await _openEditorDialog(tester, initial: initial);

    final removeRuleButton =
        find.byKey(const Key('remove-routing-rule-rule-remove'));
    await tester.ensureVisible(removeRuleButton);
    await tester.pumpAndSettle();
    await tester.tap(removeRuleButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    final removeGroupButton =
        find.byKey(const Key('remove-policy-group-group-remove'));
    await tester.ensureVisible(removeGroupButton);
    await tester.pumpAndSettle();
    await tester.tap(removeGroupButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(completer.isCompleted, isTrue);
    final profile = await completer.future;
    expect(profile, isNotNull);
    expect(profile!.routing.rules, isEmpty);
    expect(profile.routing.policyGroups, isEmpty);
  });
}
