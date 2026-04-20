import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/controller/domain/client_connection_status.dart';
import 'package:trojan_pro_client/features/controller/domain/controller_runtime_session.dart';
import 'package:trojan_pro_client/features/controller/domain/failure_family.dart';
import 'package:trojan_pro_client/features/profiles/presentation/connect_timeline_card.dart';
import 'package:trojan_pro_client/features/profiles/presentation/next_action_policy.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('shows planned → launching stage progression while connecting',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(
        ConnectTimelineCard(
          status: ClientConnectionStatus(
            phase: ClientConnectionPhase.connecting,
            message: 'Launch plan accepted. Preparing managed runtime config.',
            updatedAt: DateTime.parse('2026-04-20T02:00:00.000Z'),
            activeProfileId: 'sample-hk-1',
          ),
          runtimeSession: ControllerRuntimeSession(
            isRunning: true,
            updatedAt: DateTime.now(),
            phase: ControllerRuntimePhase.launching,
            expectedLocalSocksPort: 10808,
          ),
          failureFamily: FailureFamily.unknown,
          nextAction: ProfileNextActionDecision.none,
        ),
      ),
    );

    expect(find.textContaining('Current stage: launching'), findsOneWidget);
    expect(find.textContaining('planned • completed'), findsOneWidget);
    expect(find.textContaining('launching • active'), findsOneWidget);
    expect(find.textContaining('alive • pending'), findsOneWidget);
    expect(find.textContaining('session-ready • pending'), findsOneWidget);
  });

  testWidgets('shows failure family + next action on error',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(
        ConnectTimelineCard(
          status: ClientConnectionStatus(
            phase: ClientConnectionPhase.error,
            message: 'Runtime session exited with code 7.',
            updatedAt: DateTime.parse('2026-04-20T02:00:00.000Z'),
            activeProfileId: 'sample-hk-1',
            errorCode: 'RUNTIME_SESSION_EXIT_NONZERO',
            failureFamilyHint: 'connect',
          ),
          runtimeSession: ControllerRuntimeSession(
            isRunning: false,
            updatedAt: DateTime.now(),
            phase: ControllerRuntimePhase.failed,
            expectedLocalSocksPort: 10808,
            lastExitCode: 7,
          ),
          failureFamily: FailureFamily.connect,
          nextAction: const ProfileNextActionDecision(
            type: ProfileNextActionType.retryConnect,
            label: 'Retry Connect Test',
            detail: 'Retry after preserving current evidence.',
          ),
        ),
      ),
    );

    expect(find.textContaining('Failure family: Connect'), findsOneWidget);
    expect(find.textContaining('Next action: Retry Connect Test'), findsOneWidget);
  });

  testWidgets('shows waiting for exit confirmation during disconnecting',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(
        ConnectTimelineCard(
          status: ClientConnectionStatus(
            phase: ClientConnectionPhase.disconnecting,
            message: 'Disconnecting current session...',
            updatedAt: DateTime.parse('2026-04-20T02:00:00.000Z'),
            activeProfileId: 'sample-hk-1',
          ),
          runtimeSession: ControllerRuntimeSession(
            isRunning: true,
            updatedAt: DateTime.now(),
            phase: ControllerRuntimePhase.alive,
            stopRequested: true,
            stopRequestedAt: DateTime.now(),
            expectedLocalSocksPort: 10808,
          ),
          failureFamily: FailureFamily.unknown,
          nextAction: ProfileNextActionDecision.none,
        ),
      ),
    );

    expect(
      find.textContaining('Waiting for exit confirmation before marking disconnected.'),
      findsOneWidget,
    );
  });
}
