import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/controller/domain/client_connection_status.dart';
import 'package:trojan_pro_client/features/controller/domain/controller_runtime_session.dart';
import 'package:trojan_pro_client/features/controller/domain/runtime_action_safety.dart';
import 'package:trojan_pro_client/features/controller/domain/runtime_operator_advice.dart';
import 'package:trojan_pro_client/features/controller/domain/runtime_posture.dart';
import 'package:trojan_pro_client/features/dashboard/application/connection_lifecycle_view_model.dart';
import 'package:trojan_pro_client/features/dashboard/presentation/dashboard_guide_policy.dart';
import 'package:trojan_pro_client/features/profiles/domain/client_profile.dart';

ClientProfile _profile({
  String id = 'sample-hk-1',
  String name = 'Sample • Hong Kong',
  bool hasStoredPassword = true,
}) {
  return ClientProfile(
    id: id,
    name: name,
    serverHost: 'hk.example.com',
    serverPort: 443,
    sni: 'hk.example.com',
    localSocksPort: 10808,
    verifyTls: true,
    hasStoredPassword: hasStoredPassword,
    updatedAt: DateTime.parse('2026-03-29T00:00:00.000Z'),
  );
}

void main() {
  test('stale connected runtime produces revalidation guide', () {
    final profile = _profile();
    final status = ClientConnectionStatus(
      phase: ClientConnectionPhase.connected,
      message: 'Runtime session is ready.',
      updatedAt: DateTime.now(),
      activeProfileId: profile.id,
    );
    final session = ControllerRuntimeSession(
      isRunning: true,
      updatedAt: DateTime.now().subtract(const Duration(minutes: 3)),
      phase: ControllerRuntimePhase.sessionReady,
    );
    final posture = describeRuntimePosture(
      runtimeMode: 'real-runtime-boundary',
      backendKind: 'real-shell-controller',
    );
    final advice = RuntimeOperatorAdvice.resolve(
      status: status,
      session: session,
      posture: posture,
      troubleshootingAvailable: true,
    );

    final guide = DashboardGuidePolicy.resolve(
      lifecycle: ConnectionLifecycleViewModel.fromStatus(
        status: status,
        selectedProfile: profile,
      ),
      selectedProfile: profile,
      activeProfile: profile,
      status: status,
      posture: posture,
      runtimeSession: session,
      operatorAdvice: advice,
      readiness: null,
    );

    expect(guide.title, 'Connection state needs revalidation');
    expect(guide.primaryAction, DashboardGuideAction.openAdvanced);
    expect(guide.secondaryAction, DashboardGuideAction.disconnectNow);
    expect(guide.operatorTitle, 'Recommended right now');
    expect(guide.operatorBody, contains('Open Troubleshooting first'));
    expect(guide.actionSafety.state, RuntimeActionSafetyState.revalidateFirst);
    expect(guide.actionSafety.blocksRetry, isTrue);
    expect(guide.secondaryAction, DashboardGuideAction.disconnectNow);
  });

  test('idle missing-password state still routes to profiles', () {
    final profile = _profile(hasStoredPassword: false);
    final status = ClientConnectionStatus.disconnected();
    final posture = describeRuntimePosture(
      runtimeMode: 'stubbed-local-boundary',
      backendKind: 'fake-shell-controller',
    );

    final guide = DashboardGuidePolicy.resolve(
      lifecycle: ConnectionLifecycleViewModel.fromStatus(
        status: status,
        selectedProfile: profile,
      ),
      selectedProfile: profile,
      activeProfile: null,
      status: status,
      posture: posture,
      runtimeSession: ControllerRuntimeSession(
        isRunning: false,
        updatedAt: DateTime.now(),
        phase: ControllerRuntimePhase.stopped,
      ),
      operatorAdvice: RuntimeOperatorAdvice.none,
      readiness: null,
    );

    expect(guide.title, 'Save the password before testing');
    expect(guide.primaryAction, DashboardGuideAction.openProfiles);
  });

  test('error runtime with residual evidence prefers troubleshooting over retry shortcut', () {
    final profile = _profile();
    final status = ClientConnectionStatus(
      phase: ClientConnectionPhase.error,
      message: 'Runtime session exited with code 7.',
      updatedAt: DateTime.now(),
      activeProfileId: profile.id,
    );
    final session = ControllerRuntimeSession(
      isRunning: false,
      updatedAt: DateTime.now(),
      phase: ControllerRuntimePhase.failed,
      lastExitCode: 7,
    );
    final posture = describeRuntimePosture(
      runtimeMode: 'real-runtime-boundary',
      backendKind: 'real-shell-controller',
    );
    final advice = RuntimeOperatorAdvice.resolve(
      status: status,
      session: session,
      posture: posture,
      troubleshootingAvailable: true,
    );

    final guide = DashboardGuidePolicy.resolve(
      lifecycle: ConnectionLifecycleViewModel.fromStatus(
        status: status,
        selectedProfile: profile,
      ),
      selectedProfile: profile,
      activeProfile: profile,
      status: status,
      posture: posture,
      runtimeSession: session,
      operatorAdvice: advice,
      readiness: null,
    );

    expect(guide.primaryAction, DashboardGuideAction.openAdvanced);
    expect(guide.primaryLabel, 'Open Troubleshooting');
    expect(guide.secondaryAction, isNull);
    expect(
      guide.operatorTitle,
      'Recommended right now: capture a support snapshot first',
    );
    expect(guide.operatorBody, contains('preserve the current runtime evidence'));
    expect(guide.actionSafety.state,
        RuntimeActionSafetyState.captureSnapshotFirst);
  });

  test('disconnecting stop-pending runtime uses exit confirmation headline', () {
    final profile = _profile();
    final status = ClientConnectionStatus(
      phase: ClientConnectionPhase.disconnecting,
      message: 'Disconnecting current session...',
      updatedAt: DateTime.now(),
      activeProfileId: profile.id,
    );
    final session = ControllerRuntimeSession(
      isRunning: true,
      updatedAt: DateTime.now().subtract(const Duration(seconds: 10)),
      phase: ControllerRuntimePhase.alive,
      stopRequested: true,
      stopRequestedAt: DateTime.now().subtract(const Duration(seconds: 5)),
    );
    final posture = describeRuntimePosture(
      runtimeMode: 'real-runtime-boundary',
      backendKind: 'real-shell-controller',
    );
    final advice = RuntimeOperatorAdvice.resolve(
      status: status,
      session: session,
      posture: posture,
      troubleshootingAvailable: true,
    );

    final guide = DashboardGuidePolicy.resolve(
      lifecycle: ConnectionLifecycleViewModel.fromStatus(
        status: status,
        selectedProfile: profile,
      ),
      selectedProfile: profile,
      activeProfile: profile,
      status: status,
      posture: posture,
      runtimeSession: session,
      operatorAdvice: advice,
      readiness: null,
    );

    expect(guide.title, 'Exit confirmation pending');
    expect(guide.body, contains('fully closed yet'));
    expect(guide.primaryAction, DashboardGuideAction.openAdvanced);
    expect(
      guide.operatorTitle,
      'Recommended right now: capture a support snapshot first',
    );
    expect(guide.operatorBody, contains('capture the current support evidence'));
    expect(guide.actionSafety.state,
        RuntimeActionSafetyState.waitForExitConfirmation);
    expect(guide.actionSafety.recommendsSnapshotFirst, isTrue);
  });
}
