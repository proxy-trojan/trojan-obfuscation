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
}
