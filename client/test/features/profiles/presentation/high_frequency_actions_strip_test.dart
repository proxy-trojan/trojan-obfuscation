import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/profiles/presentation/high_frequency_actions_strip.dart';

void main() {
  testWidgets('renders quick connect/disconnect/switch actions',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HighFrequencyActionsStrip(
            onQuickConnect: () {},
            onQuickDisconnect: () {},
            onSwitchProfile: () {},
          ),
        ),
      ),
    );

    expect(find.text('Quick Connect'), findsOneWidget);
    expect(find.text('Quick Disconnect'), findsOneWidget);
    expect(find.text('Switch Profile'), findsOneWidget);
  });

  testWidgets('disables all actions when disabled flag is true',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HighFrequencyActionsStrip(
            enabled: false,
            onQuickConnect: () {},
            onQuickDisconnect: () {},
            onSwitchProfile: () {},
          ),
        ),
      ),
    );

    final connect = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Quick Connect'),
    );
    final disconnect = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Quick Disconnect'),
    );
    final switchProfile = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Switch Profile'),
    );

    expect(connect.onPressed, isNull);
    expect(disconnect.onPressed, isNull);
    expect(switchProfile.onPressed, isNull);
  });
}
