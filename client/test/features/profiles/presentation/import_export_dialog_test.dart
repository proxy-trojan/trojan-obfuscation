import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/profiles/presentation/import_export_dialog.dart';

Future<Completer<String?>> _openPathDialog(
  WidgetTester tester, {
  required String title,
  required String hintText,
  String? initialValue,
  String confirmLabel = 'Confirm',
}) async {
  final completer = Completer<String?>();

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) {
            return FilledButton(
              onPressed: () {
                showPathInputDialog(
                  context,
                  title: title,
                  hintText: hintText,
                  initialValue: initialValue,
                  confirmLabel: confirmLabel,
                ).then(completer.complete);
              },
              child: const Text('Open Path Dialog'),
            );
          },
        ),
      ),
    ),
  );

  await tester.tap(find.text('Open Path Dialog'));
  await tester.pumpAndSettle();
  return completer;
}

Future<Completer<String?>> _openImportTextDialog(WidgetTester tester) async {
  final completer = Completer<String?>();

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) {
            return FilledButton(
              onPressed: () {
                showImportTextDialog(context).then(completer.complete);
              },
              child: const Text('Open Import Dialog'),
            );
          },
        ),
      ),
    ),
  );

  await tester.tap(find.text('Open Import Dialog'));
  await tester.pumpAndSettle();
  return completer;
}

void main() {
  testWidgets('path dialog seeds initial value and returns trimmed path',
      (WidgetTester tester) async {
    final completer = await _openPathDialog(
      tester,
      title: 'Export Profile To File',
      hintText: '/path/to/exported-profile.json',
      initialValue: '/tmp/default-profile.json',
      confirmLabel: 'Save',
    );

    expect(find.text('Export Profile To File'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, '/tmp/default-profile.json');

    await tester.enterText(
      find.byType(TextField),
      '  /tmp/custom-profile.json  ',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(await completer.future, '/tmp/custom-profile.json');
  });

  testWidgets('path dialog returns null when cancelled',
      (WidgetTester tester) async {
    final completer = await _openPathDialog(
      tester,
      title: 'Import Profile From File',
      hintText: '/path/to/profile.json',
      confirmLabel: 'Load',
    );

    expect(find.text('Import Profile From File'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(await completer.future, isNull);
  });

  testWidgets('import text dialog returns pasted payload',
      (WidgetTester tester) async {
    final completer = await _openImportTextDialog(tester);

    const payload = '{"profile":{"name":"Imported Node"}}';
    await tester.enterText(find.byType(TextField), payload);
    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    await tester.pumpAndSettle();

    expect(await completer.future, payload);
  });
}
