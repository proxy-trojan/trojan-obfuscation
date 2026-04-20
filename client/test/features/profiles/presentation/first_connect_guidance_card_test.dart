import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/profiles/presentation/first_connect_guidance_card.dart';

void main() {
  testWidgets('shows blocking reason and next step before first connect',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FirstConnectGuidanceCard(
            blockingReason: 'MISSING_TROJAN_PASSWORD',
            nextAction: 'Set Trojan password and retry connect.',
          ),
        ),
      ),
    );

    expect(find.textContaining('MISSING_TROJAN_PASSWORD'), findsOneWidget);
    expect(find.textContaining('Next step'), findsOneWidget);
    expect(find.text('Set Password'), findsNothing);
  });

  testWidgets('shows ready message when no blocker exists',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FirstConnectGuidanceCard(
            blockingReason: null,
            nextAction: 'Connect now.',
          ),
        ),
      ),
    );

    expect(find.textContaining('Ready for first connect'), findsOneWidget);
    expect(find.textContaining('Next step'), findsOneWidget);
  });

  testWidgets('renders actionable next step button when action is provided',
      (WidgetTester tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FirstConnectGuidanceCard(
            blockingReason: 'Check runtime path',
            nextAction: 'Open troubleshooting to revalidate runtime path.',
            actionLabel: 'Open Troubleshooting',
            onAction: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.widgetWithText(OutlinedButton, 'Open Troubleshooting'),
        findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Open Troubleshooting'));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
