import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/profiles/domain/client_profile.dart';
import 'package:trojan_pro_client/features/profiles/presentation/profile_editor_dialog.dart';

Future<Completer<ClientProfile?>> _openEditorDialog(WidgetTester tester) async {
  final resultCompleter = Completer<ClientProfile?>();

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) {
            return FilledButton(
              onPressed: () {
                showProfileEditorDialog(context).then(resultCompleter.complete);
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
}
