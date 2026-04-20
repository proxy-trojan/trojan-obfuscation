import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/controller/domain/client_connection_status.dart';
import 'package:trojan_pro_client/features/controller/domain/controller_runtime_session.dart';
import 'package:trojan_pro_client/features/controller/domain/failure_family.dart';
import 'package:trojan_pro_client/features/controller/domain/runtime_action_safety.dart';
import 'package:trojan_pro_client/features/controller/domain/runtime_operator_advice.dart';
import 'package:trojan_pro_client/features/controller/domain/runtime_posture.dart';
import 'package:trojan_pro_client/features/dashboard/application/connection_lifecycle_view_model.dart';
import 'package:trojan_pro_client/features/dashboard/presentation/dashboard_guide_policy.dart';
import 'package:trojan_pro_client/features/profiles/domain/client_profile.dart';
import 'package:trojan_pro_client/features/profiles/presentation/next_action_policy.dart';
import 'package:trojan_pro_client/features/readiness/domain/readiness_report.dart';

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

ClientConnectionStatus _status({
  ClientConnectionPhase phase = ClientConnectionPhase.disconnected,
  String message = 'Disconnected',
  String? activeProfileId = 'sample-hk-1',
  String? errorCode,
  String? failureFamilyHint,
}) {
  return ClientConnectionStatus(
    phase: phase,
    message: message,
    updatedAt: DateTime.parse('2026-04-20T02:00:00.000Z'),
    activeProfileId: activeProfileId,
    errorCode: errorCode,
    failureFamilyHint: failureFamilyHint,
  );
}

ControllerRuntimeSession _session({
  bool isRunning = false,
  ControllerRuntimePhase phase = ControllerRuntimePhase.stopped,
  bool stopRequested = false,
  Duration age = Duration.zero,
  int? lastExitCode,
}) {
  return ControllerRuntimeSession(
    isRunning: isRunning,
    updatedAt: DateTime.now().subtract(age),
    phase: phase,
    stopRequested: stopRequested,
    stopRequestedAt: stopRequested
        ? DateTime.now().subtract(const Duration(seconds: 5))
        : null,
    lastExitCode: lastExitCode,
  );
}

RuntimePosture _posture({
  String runtimeMode = 'real-runtime-boundary',
  String backendKind = 'real-shell-controller',
}) {
  return describeRuntimePosture(
    runtimeMode: runtimeMode,
    backendKind: backendKind,
  );
}

ReadinessReport _blockedReadiness({
  required ReadinessDomain domain,
  required String summary,
  String? detail,
  ReadinessAction? action,
  String? actionLabel,
}) {
  return ReadinessReport.fromChecks(
    <ReadinessCheck>[
      ReadinessCheck(
        domain: domain,
        level: ReadinessLevel.blocked,
        summary: summary,
        detail: detail,
        action: action,
        actionLabel: actionLabel,
      ),
    ],
    generatedAt: DateTime.parse('2026-04-20T01:55:00.000Z'),
  );
}

DashboardGuidePolicy _resolveGuide({
  required ClientConnectionStatus status,
  required ClientProfile? selectedProfile,
  required ClientProfile? activeProfile,
  required RuntimePosture posture,
  required ControllerRuntimeSession session,
  required bool troubleshootingAvailable,
  bool settingsAvailable = true,
  ReadinessReport? readiness,
}) {
  final advice = RuntimeOperatorAdvice.resolve(
    status: status,
    session: session,
    posture: posture,
    troubleshootingAvailable: troubleshootingAvailable,
  );

  return DashboardGuidePolicy.resolve(
    lifecycle: ConnectionLifecycleViewModel.fromStatus(
      status: status,
      selectedProfile: selectedProfile,
    ),
    selectedProfile: selectedProfile,
    activeProfile: activeProfile,
    status: status,
    posture: posture,
    runtimeSession: session,
    operatorAdvice: advice,
    readiness: readiness,
    settingsAvailable: settingsAvailable,
  );
}

ProfileNextActionDecision _resolveProfileDecision({
  required ClientConnectionStatus status,
  required ReadinessReport? readiness,
  required RuntimePosture posture,
  required ControllerRuntimeSession session,
  required bool troubleshootingAvailable,
  required bool settingsAvailable,
}) {
  final parsedFamily = parseFailureFamily(status.failureFamilyHint);
  final family = parsedFamily == FailureFamily.unknown
      ? classifyFailureFamily(
          errorCode: status.errorCode,
          summary: status.message,
          detail: status.message,
          phase: status.phase.name,
        )
      : parsedFamily;

  return ProfileNextActionPolicy.resolve(
    status: status,
    readinessReport: readiness,
    failureFamily: family,
    troubleshootingAvailable: troubleshootingAvailable,
    settingsAvailable: settingsAvailable,
    runtimePosture: posture,
    runtimeSession: session,
  );
}

ProfileNextActionType? _mapGuidePrimaryAction(DashboardGuideAction action) {
  return switch (action) {
    DashboardGuideAction.openProfiles => ProfileNextActionType.openProfiles,
    DashboardGuideAction.openAdvanced =>
      ProfileNextActionType.openTroubleshooting,
    DashboardGuideAction.openSettings => ProfileNextActionType.openSettings,
    DashboardGuideAction.retryNow => ProfileNextActionType.retryConnect,
    DashboardGuideAction.connectNow ||
    DashboardGuideAction.disconnectNow =>
      null,
  };
}

void main() {
  test('stale connected runtime produces revalidation guide', () {
    final profile = _profile();
    final status = _status(
      phase: ClientConnectionPhase.connected,
      message: 'Runtime session is ready.',
      activeProfileId: profile.id,
    );
    final session = _session(
      isRunning: true,
      phase: ControllerRuntimePhase.sessionReady,
      age: const Duration(minutes: 3),
    );
    final posture = _posture();

    final guide = _resolveGuide(
      status: status,
      selectedProfile: profile,
      activeProfile: profile,
      posture: posture,
      session: session,
      troubleshootingAvailable: true,
    );

    expect(guide.title, 'Connection state needs revalidation');
    expect(guide.primaryAction, DashboardGuideAction.openAdvanced);
    expect(guide.secondaryAction, DashboardGuideAction.disconnectNow);
    expect(guide.operatorTitle, 'Recommended right now');
    expect(guide.operatorBody, contains('Open Troubleshooting first'));
    expect(guide.actionSafety.state, RuntimeActionSafetyState.revalidateFirst);
    expect(guide.actionSafety.blocksRetry, isTrue);
  });

  test('idle missing-password state still routes to profiles', () {
    final profile = _profile(hasStoredPassword: false);
    final status = _status();
    final posture = _posture(
      runtimeMode: 'stubbed-local-boundary',
      backendKind: 'fake-shell-controller',
    );

    final guide = _resolveGuide(
      status: status,
      selectedProfile: profile,
      activeProfile: null,
      posture: posture,
      session: _session(),
      troubleshootingAvailable: true,
    );

    expect(guide.title, 'Save the password before testing');
    expect(guide.primaryAction, DashboardGuideAction.openProfiles);
  });

  test(
      'error runtime with residual evidence prefers troubleshooting over retry shortcut',
      () {
    final profile = _profile();
    final status = _status(
      phase: ClientConnectionPhase.error,
      message: 'Runtime session exited with code 7.',
      activeProfileId: profile.id,
    );
    final session = _session(
      isRunning: false,
      phase: ControllerRuntimePhase.failed,
      lastExitCode: 7,
    );
    final posture = _posture();

    final guide = _resolveGuide(
      status: status,
      selectedProfile: profile,
      activeProfile: profile,
      posture: posture,
      session: session,
      troubleshootingAvailable: true,
    );

    expect(guide.primaryAction, DashboardGuideAction.openAdvanced);
    expect(guide.primaryLabel, 'Open Troubleshooting');
    expect(guide.secondaryAction, isNull);
    expect(
      guide.operatorTitle,
      'Recommended right now: capture a support snapshot first',
    );
    expect(
        guide.operatorBody, contains('preserve the current runtime evidence'));
    expect(
      guide.actionSafety.state,
      RuntimeActionSafetyState.captureSnapshotFirst,
    );
  });

  test('disconnecting stop-pending runtime uses exit confirmation headline',
      () {
    final profile = _profile();
    final status = _status(
      phase: ClientConnectionPhase.disconnecting,
      message: 'Disconnecting current session...',
      activeProfileId: profile.id,
    );
    final session = _session(
      isRunning: true,
      phase: ControllerRuntimePhase.alive,
      stopRequested: true,
      age: const Duration(seconds: 10),
    );
    final posture = _posture();

    final guide = _resolveGuide(
      status: status,
      selectedProfile: profile,
      activeProfile: profile,
      posture: posture,
      session: session,
      troubleshootingAvailable: true,
    );

    expect(guide.title, 'Exit confirmation pending');
    expect(guide.body, contains('fully closed yet'));
    expect(guide.primaryAction, DashboardGuideAction.openAdvanced);
    expect(
      guide.operatorTitle,
      'Recommended right now: capture a support snapshot first',
    );
    expect(
        guide.operatorBody, contains('capture the current support evidence'));
    expect(
      guide.actionSafety.state,
      RuntimeActionSafetyState.waitForExitConfirmation,
    );
    expect(guide.actionSafety.recommendsSnapshotFirst, isTrue);
  });

  test('error config keeps same action label and detail as profile next action',
      () {
    final profile = _profile();
    final status = _status(
      phase: ClientConnectionPhase.error,
      message: 'Config invalid.',
      activeProfileId: profile.id,
      errorCode: 'CONFIG_INVALID',
      failureFamilyHint: 'config',
    );
    final session = _session();
    final posture = _posture();

    final guide = _resolveGuide(
      status: status,
      selectedProfile: profile,
      activeProfile: profile,
      posture: posture,
      session: session,
      troubleshootingAvailable: true,
    );

    final profileDecision = _resolveProfileDecision(
      status: status,
      readiness: null,
      posture: posture,
      session: session,
      troubleshootingAvailable: true,
      settingsAvailable: true,
    );

    expect(_mapGuidePrimaryAction(guide.primaryAction), profileDecision.type);
    expect(guide.primaryLabel, profileDecision.label);
    expect(guide.body, profileDecision.detail);
  });

  test(
      'error unknown without troubleshooting keeps same fallback action as profile',
      () {
    final profile = _profile();
    final status = _status(
      phase: ClientConnectionPhase.error,
      message: 'Unknown runtime failure.',
      activeProfileId: profile.id,
      errorCode: 'UNCLASSIFIED_RUNTIME_FAILURE',
      failureFamilyHint: 'unknown',
    );
    final session = _session();
    final posture = _posture();

    final guide = _resolveGuide(
      status: status,
      selectedProfile: profile,
      activeProfile: profile,
      posture: posture,
      session: session,
      troubleshootingAvailable: false,
    );

    final profileDecision = _resolveProfileDecision(
      status: status,
      readiness: null,
      posture: posture,
      session: session,
      troubleshootingAvailable: false,
      settingsAvailable: true,
    );

    expect(_mapGuidePrimaryAction(guide.primaryAction), profileDecision.type);
    expect(guide.primaryLabel, profileDecision.label);
    expect(guide.body, profileDecision.detail);
  });

  test(
      'blocked readiness openSettings recommendation falls back consistently when settings are unavailable',
      () {
    final profile = _profile();
    final status = _status(
      phase: ClientConnectionPhase.disconnected,
      message: 'Disconnected',
      activeProfileId: profile.id,
    );
    final session = _session();
    final posture = _posture();
    final readiness = _blockedReadiness(
      domain: ReadinessDomain.secureStorage,
      summary: 'secure storage unavailable',
      detail: 'Secure storage provider is unavailable.',
      action: ReadinessAction.openSettings,
      actionLabel: 'Open Settings',
    );

    final guide = _resolveGuide(
      status: status,
      selectedProfile: profile,
      activeProfile: null,
      posture: posture,
      session: session,
      troubleshootingAvailable: true,
      settingsAvailable: false,
      readiness: readiness,
    );

    final profileDecision = _resolveProfileDecision(
      status: status,
      readiness: readiness,
      posture: posture,
      session: session,
      troubleshootingAvailable: true,
      settingsAvailable: false,
    );

    expect(_mapGuidePrimaryAction(guide.primaryAction), profileDecision.type);
    expect(guide.primaryLabel, profileDecision.label);
    expect(guide.body, profileDecision.detail);
  });
}
