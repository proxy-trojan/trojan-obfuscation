import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/profiles/domain/client_profile.dart';
import 'package:trojan_pro_client/features/profiles/presentation/profile_editor_dialog.dart';
import 'package:trojan_pro_client/features/routing/domain/routing_models.dart';
import 'package:trojan_pro_client/features/routing/domain/routing_profile_config.dart';

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

    final routingModeDropdown = find.byKey(const Key('routing-mode-dropdown'));
    await tester.ensureVisible(routingModeDropdown);
    await tester.pumpAndSettle();
    await tester.tap(routingModeDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('global').last, warnIfMissed: false);
    await tester.pumpAndSettle();

    final routingDefaultActionDropdown =
        find.byKey(const Key('routing-default-action-dropdown'));
    await tester.ensureVisible(routingDefaultActionDropdown);
    await tester.pumpAndSettle();
    await tester.tap(routingDefaultActionDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('direct').last, warnIfMissed: false);
    await tester.pumpAndSettle();

    final routingGlobalActionDropdown =
        find.byKey(const Key('routing-global-action-dropdown'));
    await tester.ensureVisible(routingGlobalActionDropdown);
    await tester.pumpAndSettle();
    await tester.tap(routingGlobalActionDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('block').last, warnIfMissed: false);
    await tester.pumpAndSettle();

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
}
