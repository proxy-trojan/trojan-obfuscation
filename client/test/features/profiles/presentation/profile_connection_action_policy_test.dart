import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/controller/domain/client_connection_status.dart';
import 'package:trojan_pro_client/features/controller/domain/controller_runtime_session.dart';
import 'package:trojan_pro_client/features/controller/domain/runtime_action_safety.dart';
import 'package:trojan_pro_client/features/controller/domain/runtime_posture.dart';
import 'package:trojan_pro_client/features/profiles/presentation/profile_connection_action_policy.dart';
import 'package:trojan_pro_client/features/readiness/domain/readiness_report.dart';

void main() {
  test('stale connected session routes to troubleshooting when available', () {
    final policy = ProfileConnectionActionPolicy.resolve(
      hasStoredPassword: true,
      active: true,
      status: ClientConnectionStatus(
        phase: ClientConnectionPhase.connected,
        message: 'Runtime session is ready.',
        updatedAt: DateTime.now(),
        activeProfileId: 'sample-hk-1',
      ),
      runtimePosture: describeRuntimePosture(
        runtimeMode: 'real-runtime-boundary',
        backendKind: 'real-shell-controller',
      ),
      runtimeSession: ControllerRuntimeSession(
        isRunning: true,
        updatedAt: DateTime.now().subtract(const Duration(minutes: 3)),
        phase: ControllerRuntimePhase.sessionReady,
      ),
      readinessReport: null,
      hasConnectedElsewhere: false,
      onOpenAdvancedAvailable: true,
    );

    expect(policy.buttonLabel, 'Revalidate in Troubleshooting');
    expect(policy.buttonEnabled, isTrue);
    expect(policy.primaryAction,
        ProfileConnectionPrimaryAction.openTroubleshooting);
  });

  test('disconnecting session surfaces recovery guidance instead of idle hint', () {
    final policy = ProfileConnectionActionPolicy.resolve(
      hasStoredPassword: true,
      active: true,
      status: ClientConnectionStatus(
        phase: ClientConnectionPhase.disconnecting,
        message: 'Disconnecting current session...',
        updatedAt: DateTime.now(),
        activeProfileId: 'sample-hk-1',
      ),
      runtimePosture: describeRuntimePosture(
        runtimeMode: 'real-runtime-boundary',
        backendKind: 'real-shell-controller',
      ),
      runtimeSession: ControllerRuntimeSession(
        isRunning: true,
        updatedAt: DateTime.now().subtract(const Duration(seconds: 10)),
        phase: ControllerRuntimePhase.alive,
        stopRequested: true,
        stopRequestedAt: DateTime.now().subtract(const Duration(seconds: 5)),
      ),
      readinessReport: null,
      hasConnectedElsewhere: false,
      onOpenAdvancedAvailable: true,
    );

    expect(policy.buttonLabel, 'Open Troubleshooting');
    expect(policy.buttonEnabled, isTrue);
    expect(policy.statusHint, contains('exit confirmation'));
    expect(policy.primaryAction,
        ProfileConnectionPrimaryAction.openTroubleshooting);
    expect(policy.actionSafety.state,
        RuntimeActionSafetyState.waitForExitConfirmation);
    expect(policy.actionSafety.recommendsSnapshotFirst, isTrue);
  });

  test('readiness blocked connect returns blocked policy', () {
    final policy = ProfileConnectionActionPolicy.resolve(
      hasStoredPassword: true,
      active: false,
      status: ClientConnectionStatus.disconnected(),
      runtimePosture: describeRuntimePosture(
        runtimeMode: 'stubbed-local-boundary',
        backendKind: 'fake-shell-controller',
      ),
      runtimeSession: ControllerRuntimeSession(
        isRunning: false,
        updatedAt: DateTime.now(),
        phase: ControllerRuntimePhase.stopped,
      ),
      readinessReport: ReadinessReport.fromChecks(
        const <ReadinessCheck>[
          ReadinessCheck(
            domain: ReadinessDomain.config,
            level: ReadinessLevel.blocked,
            summary: 'server host missing',
            detail: 'server host missing',
            action: ReadinessAction.openProfiles,
            actionLabel: 'Open Profiles',
          ),
        ],
        generatedAt: DateTime.now(),
      ),
      hasConnectedElsewhere: false,
      onOpenAdvancedAvailable: false,
    );

    expect(policy.buttonLabel, 'Connect Test Blocked');
    expect(policy.buttonEnabled, isFalse);
    expect(policy.statusHint, contains('Readiness blocked'));
  });
}
