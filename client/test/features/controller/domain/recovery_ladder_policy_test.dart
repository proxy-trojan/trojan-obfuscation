import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/controller/domain/client_connection_status.dart';
import 'package:trojan_pro_client/features/controller/domain/controller_runtime_session.dart';
import 'package:trojan_pro_client/features/controller/domain/failure_family.dart';
import 'package:trojan_pro_client/features/controller/domain/recovery_ladder_policy.dart';
import 'package:trojan_pro_client/features/controller/domain/runtime_posture.dart';
import 'package:trojan_pro_client/features/readiness/domain/readiness_report.dart';

ClientConnectionStatus _status({
  ClientConnectionPhase phase = ClientConnectionPhase.disconnected,
  String message = 'Disconnected',
  String? errorCode,
  String? failureFamilyHint,
}) {
  return ClientConnectionStatus(
    phase: phase,
    message: message,
    updatedAt: DateTime.parse('2026-04-20T02:00:00.000Z'),
    activeProfileId: 'sample-hk-1',
    errorCode: errorCode,
    failureFamilyHint: failureFamilyHint,
  );
}

ControllerRuntimeSession _session({
  bool isRunning = false,
  ControllerRuntimePhase phase = ControllerRuntimePhase.stopped,
  bool stopRequested = false,
  Duration age = Duration.zero,
  int? exitCode,
}) {
  return ControllerRuntimeSession(
    isRunning: isRunning,
    updatedAt: DateTime.now().subtract(age),
    phase: phase,
    stopRequested: stopRequested,
    stopRequestedAt: stopRequested
        ? DateTime.now().subtract(const Duration(seconds: 3))
        : null,
    lastExitCode: exitCode,
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

ReadinessReport _blockedReport(ReadinessCheck check) {
  return ReadinessReport.fromChecks(
    <ReadinessCheck>[check],
    generatedAt: DateTime.parse('2026-04-20T01:55:00.000Z'),
  );
}

void main() {
  group('RecoveryLadderPolicy', () {
    test('blocked readiness openProfiles recommendation keeps profiles action',
        () {
      final decision = RecoveryLadderPolicy.resolve(
        input: RecoveryLadderPolicyInput(
          status: _status(),
          readinessReport: _blockedReport(
            const ReadinessCheck(
              domain: ReadinessDomain.profile,
              level: ReadinessLevel.blocked,
              summary: 'profile missing host',
              detail: 'Set a valid server host first.',
              action: ReadinessAction.openProfiles,
              actionLabel: 'Open Profiles',
            ),
          ),
          failureFamily: FailureFamily.unknown,
          runtimePosture: _posture(),
          runtimeSession: _session(),
          recentAction: RecoveryRecentActionContext.none,
          troubleshootingAvailable: true,
          settingsAvailable: true,
        ),
      );

      expect(decision.primaryAction, RecoveryLadderAction.openProfiles);
      expect(decision.primaryLabel, 'Open Profiles');
      expect(decision.detail, contains('server host'));
    });

    test(
        'blocked readiness openTroubleshooting recommendation uses troubleshooting when available',
        () {
      final decision = RecoveryLadderPolicy.resolve(
        input: RecoveryLadderPolicyInput(
          status: _status(),
          readinessReport: _blockedReport(
            const ReadinessCheck(
              domain: ReadinessDomain.environment,
              level: ReadinessLevel.blocked,
              summary: 'runtime binary missing',
              detail: 'Runtime binary is unavailable.',
              action: ReadinessAction.openTroubleshooting,
              actionLabel: 'Open Troubleshooting',
            ),
          ),
          failureFamily: FailureFamily.unknown,
          runtimePosture: _posture(),
          runtimeSession: _session(),
          recentAction: RecoveryRecentActionContext.none,
          troubleshootingAvailable: true,
          settingsAvailable: true,
        ),
      );

      expect(decision.primaryAction, RecoveryLadderAction.openTroubleshooting);
      expect(decision.primaryLabel, 'Open Troubleshooting');
      expect(decision.detail, contains('Runtime binary'));
    });

    test(
        'blocked readiness openTroubleshooting recommendation falls back to profiles when unavailable',
        () {
      final decision = RecoveryLadderPolicy.resolve(
        input: RecoveryLadderPolicyInput(
          status: _status(),
          readinessReport: _blockedReport(
            const ReadinessCheck(
              domain: ReadinessDomain.environment,
              level: ReadinessLevel.blocked,
              summary: 'runtime binary missing',
              detail: 'Runtime binary is unavailable.',
              action: ReadinessAction.openTroubleshooting,
              actionLabel: 'Open Troubleshooting',
            ),
          ),
          failureFamily: FailureFamily.unknown,
          runtimePosture: _posture(),
          runtimeSession: _session(),
          recentAction: RecoveryRecentActionContext.none,
          troubleshootingAvailable: false,
          settingsAvailable: true,
        ),
      );

      expect(decision.primaryAction, RecoveryLadderAction.openProfiles);
      expect(decision.primaryLabel, 'Open Profiles');
      expect(decision.detail, contains('fallback'));
    });

    test(
        'blocked readiness openSettings recommendation uses settings when available',
        () {
      final decision = RecoveryLadderPolicy.resolve(
        input: RecoveryLadderPolicyInput(
          status: _status(),
          readinessReport: _blockedReport(
            const ReadinessCheck(
              domain: ReadinessDomain.secureStorage,
              level: ReadinessLevel.blocked,
              summary: 'secure storage unavailable',
              detail: 'Secure storage provider is unavailable.',
              action: ReadinessAction.openSettings,
              actionLabel: 'Open Settings',
            ),
          ),
          failureFamily: FailureFamily.unknown,
          runtimePosture: _posture(),
          runtimeSession: _session(),
          recentAction: RecoveryRecentActionContext.none,
          troubleshootingAvailable: true,
          settingsAvailable: true,
        ),
      );

      expect(decision.primaryAction, RecoveryLadderAction.openSettings);
      expect(decision.primaryLabel, 'Open Settings');
    });

    test(
        'blocked readiness openSettings recommendation falls back to profiles when unavailable',
        () {
      final decision = RecoveryLadderPolicy.resolve(
        input: RecoveryLadderPolicyInput(
          status: _status(),
          readinessReport: _blockedReport(
            const ReadinessCheck(
              domain: ReadinessDomain.secureStorage,
              level: ReadinessLevel.blocked,
              summary: 'secure storage unavailable',
              detail: 'Secure storage provider is unavailable.',
              action: ReadinessAction.openSettings,
              actionLabel: 'Open Settings',
            ),
          ),
          failureFamily: FailureFamily.unknown,
          runtimePosture: _posture(),
          runtimeSession: _session(),
          recentAction: RecoveryRecentActionContext.none,
          troubleshootingAvailable: true,
          settingsAvailable: false,
        ),
      );

      expect(decision.primaryAction, RecoveryLadderAction.openProfiles);
      expect(decision.primaryLabel, 'Open Profiles');
      expect(decision.detail, contains('fallback'));
    });

    test('blocked readiness password domain maps to Set Password on profiles',
        () {
      final decision = RecoveryLadderPolicy.resolve(
        input: RecoveryLadderPolicyInput(
          status: _status(),
          readinessReport: _blockedReport(
            const ReadinessCheck(
              domain: ReadinessDomain.password,
              level: ReadinessLevel.blocked,
              summary: 'password missing',
              detail: 'Store Trojan password first.',
            ),
          ),
          failureFamily: FailureFamily.unknown,
          runtimePosture: _posture(),
          runtimeSession: _session(),
          recentAction: RecoveryRecentActionContext.none,
          troubleshootingAvailable: true,
          settingsAvailable: true,
        ),
      );

      expect(decision.primaryAction, RecoveryLadderAction.openProfiles);
      expect(decision.primaryLabel, 'Set Password');
      expect(decision.detail, contains('Trojan password'));
    });

    test(
        'blocked readiness secureStorage domain falls back to profiles when settings unavailable',
        () {
      final decision = RecoveryLadderPolicy.resolve(
        input: RecoveryLadderPolicyInput(
          status: _status(),
          readinessReport: _blockedReport(
            const ReadinessCheck(
              domain: ReadinessDomain.secureStorage,
              level: ReadinessLevel.blocked,
              summary: 'secure storage unavailable',
              detail: 'Secure storage provider is unavailable.',
            ),
          ),
          failureFamily: FailureFamily.unknown,
          runtimePosture: _posture(),
          runtimeSession: _session(),
          recentAction: RecoveryRecentActionContext.none,
          troubleshootingAvailable: true,
          settingsAvailable: false,
        ),
      );

      expect(decision.primaryAction, RecoveryLadderAction.openProfiles);
      expect(decision.primaryLabel, 'Open Profiles');
    });

    test(
        'blocked readiness runtime domain maps to troubleshooting when available',
        () {
      final decision = RecoveryLadderPolicy.resolve(
        input: RecoveryLadderPolicyInput(
          status: _status(),
          readinessReport: _blockedReport(
            const ReadinessCheck(
              domain: ReadinessDomain.runtimeBinary,
              level: ReadinessLevel.blocked,
              summary: 'runtime binary missing',
              detail: 'Runtime binary missing from configured path.',
            ),
          ),
          failureFamily: FailureFamily.unknown,
          runtimePosture: _posture(),
          runtimeSession: _session(),
          recentAction: RecoveryRecentActionContext.none,
          troubleshootingAvailable: true,
          settingsAvailable: true,
        ),
      );

      expect(decision.primaryAction, RecoveryLadderAction.openTroubleshooting);
      expect(decision.primaryLabel, 'Open Troubleshooting');
    });

    test('error user_input maps to set password action', () {
      final decision = RecoveryLadderPolicy.resolve(
        input: RecoveryLadderPolicyInput(
          status: _status(
            phase: ClientConnectionPhase.error,
            message: 'Trojan password missing.',
            errorCode: 'MISSING_TROJAN_PASSWORD',
            failureFamilyHint: 'user_input',
          ),
          readinessReport: null,
          failureFamily: FailureFamily.userInput,
          runtimePosture: _posture(),
          runtimeSession: _session(),
          recentAction: RecoveryRecentActionContext.connectAttempted,
          troubleshootingAvailable: true,
          settingsAvailable: true,
        ),
      );

      expect(decision.primaryAction, RecoveryLadderAction.openProfiles);
      expect(decision.primaryLabel, 'Set Password');
    });

    test('error config maps to open profiles action', () {
      final decision = RecoveryLadderPolicy.resolve(
        input: RecoveryLadderPolicyInput(
          status: _status(
            phase: ClientConnectionPhase.error,
            message: 'Config invalid.',
            errorCode: 'CONFIG_INVALID',
            failureFamilyHint: 'config',
          ),
          readinessReport: null,
          failureFamily: FailureFamily.config,
          runtimePosture: _posture(),
          runtimeSession: _session(),
          recentAction: RecoveryRecentActionContext.connectAttempted,
          troubleshootingAvailable: true,
          settingsAvailable: true,
        ),
      );

      expect(decision.primaryAction, RecoveryLadderAction.openProfiles);
      expect(decision.primaryLabel, 'Open Profiles');
    });

    test(
        'error connect maps to retry connect when no evidence-first guard is active',
        () {
      final decision = RecoveryLadderPolicy.resolve(
        input: RecoveryLadderPolicyInput(
          status: _status(
            phase: ClientConnectionPhase.error,
            message: 'Runtime session exited with code 7.',
            errorCode: 'RUNTIME_SESSION_EXIT_NONZERO',
            failureFamilyHint: 'connect',
          ),
          readinessReport: null,
          failureFamily: FailureFamily.connect,
          runtimePosture: _posture(),
          runtimeSession: _session(
            isRunning: false,
            phase: ControllerRuntimePhase.stopped,
          ),
          recentAction: RecoveryRecentActionContext.connectAttempted,
          troubleshootingAvailable: true,
          settingsAvailable: true,
        ),
      );

      expect(decision.primaryAction, RecoveryLadderAction.retryConnect);
      expect(decision.primaryLabel, 'Retry Connect Test');
    });

    test(
        'error launch maps to retry connect when no evidence-first guard is active',
        () {
      final decision = RecoveryLadderPolicy.resolve(
        input: RecoveryLadderPolicyInput(
          status: _status(
            phase: ClientConnectionPhase.error,
            message: 'Launch request rejected.',
            errorCode: 'LAUNCH_REQUEST_REJECTED',
            failureFamilyHint: 'launch',
          ),
          readinessReport: null,
          failureFamily: FailureFamily.launch,
          runtimePosture: _posture(),
          runtimeSession: _session(),
          recentAction: RecoveryRecentActionContext.connectAttempted,
          troubleshootingAvailable: true,
          settingsAvailable: true,
        ),
      );

      expect(decision.primaryAction, RecoveryLadderAction.retryConnect);
      expect(decision.primaryLabel, 'Retry Connect Test');
    });

    test(
        'error connect with stale runtime prioritizes troubleshooting evidence capture',
        () {
      final decision = RecoveryLadderPolicy.resolve(
        input: RecoveryLadderPolicyInput(
          status: _status(
            phase: ClientConnectionPhase.error,
            message: 'Runtime session exited with code 7.',
            errorCode: 'RUNTIME_SESSION_EXIT_NONZERO',
            failureFamilyHint: 'connect',
          ),
          readinessReport: null,
          failureFamily: FailureFamily.connect,
          runtimePosture: _posture(),
          runtimeSession: _session(
            isRunning: true,
            phase: ControllerRuntimePhase.alive,
            age: const Duration(minutes: 3),
          ),
          recentAction: RecoveryRecentActionContext.retryRequested,
          troubleshootingAvailable: true,
          settingsAvailable: true,
        ),
      );

      expect(decision.primaryAction, RecoveryLadderAction.openTroubleshooting);
      expect(decision.primaryLabel, 'Open Troubleshooting');
      expect(decision.detail, contains('Preserve'));
    });

    test('error environment prefers settings when available', () {
      final decision = RecoveryLadderPolicy.resolve(
        input: RecoveryLadderPolicyInput(
          status: _status(
            phase: ClientConnectionPhase.error,
            message: 'Runtime binary missing.',
            errorCode: 'RUNTIME_BINARY_MISSING',
            failureFamilyHint: 'environment',
          ),
          readinessReport: null,
          failureFamily: FailureFamily.environment,
          runtimePosture: _posture(),
          runtimeSession: _session(),
          recentAction: RecoveryRecentActionContext.connectAttempted,
          troubleshootingAvailable: true,
          settingsAvailable: true,
        ),
      );

      expect(decision.primaryAction, RecoveryLadderAction.openSettings);
      expect(decision.primaryLabel, 'Open Settings');
    });

    test(
        'error environment falls back to troubleshooting when settings unavailable',
        () {
      final decision = RecoveryLadderPolicy.resolve(
        input: RecoveryLadderPolicyInput(
          status: _status(
            phase: ClientConnectionPhase.error,
            message: 'Runtime binary missing.',
            errorCode: 'RUNTIME_BINARY_MISSING',
            failureFamilyHint: 'environment',
          ),
          readinessReport: null,
          failureFamily: FailureFamily.environment,
          runtimePosture: _posture(),
          runtimeSession: _session(),
          recentAction: RecoveryRecentActionContext.connectAttempted,
          troubleshootingAvailable: true,
          settingsAvailable: false,
        ),
      );

      expect(decision.primaryAction, RecoveryLadderAction.openTroubleshooting);
      expect(decision.primaryLabel, 'Open Troubleshooting');
    });

    test(
        'error environment falls back to profiles when no entrypoint is available',
        () {
      final decision = RecoveryLadderPolicy.resolve(
        input: RecoveryLadderPolicyInput(
          status: _status(
            phase: ClientConnectionPhase.error,
            message: 'Runtime binary missing.',
            errorCode: 'RUNTIME_BINARY_MISSING',
            failureFamilyHint: 'environment',
          ),
          readinessReport: null,
          failureFamily: FailureFamily.environment,
          runtimePosture: _posture(),
          runtimeSession: _session(),
          recentAction: RecoveryRecentActionContext.connectAttempted,
          troubleshootingAvailable: false,
          settingsAvailable: false,
        ),
      );

      expect(decision.primaryAction, RecoveryLadderAction.openProfiles);
      expect(decision.primaryLabel, 'Open Profiles');
    });

    test('error export_os maps to support bundle export action', () {
      final decision = RecoveryLadderPolicy.resolve(
        input: RecoveryLadderPolicyInput(
          status: _status(
            phase: ClientConnectionPhase.error,
            message: 'Diagnostics export failed: permission denied.',
            errorCode: 'DIAGNOSTICS_EXPORT_FAILED',
            failureFamilyHint: 'export_os',
          ),
          readinessReport: null,
          failureFamily: FailureFamily.exportOs,
          runtimePosture: _posture(),
          runtimeSession: _session(),
          recentAction: RecoveryRecentActionContext.connectAttempted,
          troubleshootingAvailable: true,
          settingsAvailable: true,
        ),
      );

      expect(decision.primaryAction, RecoveryLadderAction.exportSupportBundle);
      expect(decision.primaryLabel, 'Export Support Bundle');
    });

    test('error unknown defaults to troubleshooting when available', () {
      final decision = RecoveryLadderPolicy.resolve(
        input: RecoveryLadderPolicyInput(
          status: _status(
            phase: ClientConnectionPhase.error,
            message: 'Unknown runtime failure.',
            errorCode: 'UNCLASSIFIED_RUNTIME_FAILURE',
            failureFamilyHint: 'unknown',
          ),
          readinessReport: null,
          failureFamily: FailureFamily.unknown,
          runtimePosture: _posture(),
          runtimeSession: _session(),
          recentAction: RecoveryRecentActionContext.connectAttempted,
          troubleshootingAvailable: true,
          settingsAvailable: true,
        ),
      );

      expect(decision.primaryAction, RecoveryLadderAction.openTroubleshooting);
      expect(decision.primaryLabel, 'Open Troubleshooting');
      expect(decision.detail, contains('capture runtime evidence'));
    });

    test(
        'error unknown falls back to profiles when troubleshooting unavailable',
        () {
      final decision = RecoveryLadderPolicy.resolve(
        input: RecoveryLadderPolicyInput(
          status: _status(
            phase: ClientConnectionPhase.error,
            message: 'Unknown runtime failure.',
            errorCode: 'UNCLASSIFIED_RUNTIME_FAILURE',
            failureFamilyHint: 'unknown',
          ),
          readinessReport: null,
          failureFamily: FailureFamily.unknown,
          runtimePosture: _posture(),
          runtimeSession: _session(),
          recentAction: RecoveryRecentActionContext.connectAttempted,
          troubleshootingAvailable: false,
          settingsAvailable: true,
        ),
      );

      expect(decision.primaryAction, RecoveryLadderAction.openProfiles);
      expect(decision.primaryLabel, 'Open Profiles');
    });

    test('disconnecting state recommends troubleshooting when available', () {
      final decision = RecoveryLadderPolicy.resolve(
        input: RecoveryLadderPolicyInput(
          status: _status(
            phase: ClientConnectionPhase.disconnecting,
            message: 'Disconnecting current session...',
          ),
          readinessReport: null,
          failureFamily: FailureFamily.unknown,
          runtimePosture: _posture(),
          runtimeSession: _session(
            isRunning: true,
            phase: ControllerRuntimePhase.alive,
            stopRequested: true,
            age: const Duration(seconds: 8),
          ),
          recentAction: RecoveryRecentActionContext.disconnectRequested,
          troubleshootingAvailable: true,
          settingsAvailable: true,
        ),
      );

      expect(decision.primaryAction, RecoveryLadderAction.openTroubleshooting);
      expect(decision.primaryLabel, 'Open Troubleshooting');
      expect(decision.detail, contains('exit confirmation'));
    });

    test(
        'disconnecting state falls back to profiles when troubleshooting unavailable',
        () {
      final decision = RecoveryLadderPolicy.resolve(
        input: RecoveryLadderPolicyInput(
          status: _status(
            phase: ClientConnectionPhase.disconnecting,
            message: 'Disconnecting current session...',
          ),
          readinessReport: null,
          failureFamily: FailureFamily.unknown,
          runtimePosture: _posture(),
          runtimeSession: _session(
            isRunning: true,
            phase: ControllerRuntimePhase.alive,
            stopRequested: true,
            age: const Duration(seconds: 8),
          ),
          recentAction: RecoveryRecentActionContext.disconnectRequested,
          troubleshootingAvailable: false,
          settingsAvailable: true,
        ),
      );

      expect(decision.primaryAction, RecoveryLadderAction.openProfiles);
      expect(decision.primaryLabel, 'Open Profiles');
    });

    test('connected stale runtime recommends revalidate in troubleshooting',
        () {
      final decision = RecoveryLadderPolicy.resolve(
        input: RecoveryLadderPolicyInput(
          status: _status(
            phase: ClientConnectionPhase.connected,
            message: 'Runtime session is ready.',
          ),
          readinessReport: null,
          failureFamily: FailureFamily.unknown,
          runtimePosture: _posture(),
          runtimeSession: _session(
            isRunning: true,
            phase: ControllerRuntimePhase.sessionReady,
            age: const Duration(minutes: 3),
          ),
          recentAction: RecoveryRecentActionContext.connectAttempted,
          troubleshootingAvailable: true,
          settingsAvailable: true,
        ),
      );

      expect(decision.primaryAction, RecoveryLadderAction.openTroubleshooting);
      expect(decision.primaryLabel, 'Revalidate in Troubleshooting');
      expect(decision.detail, contains('revalidate'));
    });

    test('connected stub residual state does not force action by itself', () {
      final decision = RecoveryLadderPolicy.resolve(
        input: RecoveryLadderPolicyInput(
          status: _status(
            phase: ClientConnectionPhase.connected,
            message: 'Connected via fake controller boundary',
          ),
          readinessReport: null,
          failureFamily: FailureFamily.unknown,
          runtimePosture: _posture(
            runtimeMode: 'stubbed-local-boundary',
            backendKind: 'fake-shell-controller',
          ),
          runtimeSession: _session(
            isRunning: false,
            phase: ControllerRuntimePhase.sessionReady,
          ),
          recentAction: RecoveryRecentActionContext.connectAttempted,
          troubleshootingAvailable: true,
          settingsAvailable: true,
        ),
      );

      expect(decision.primaryAction, RecoveryLadderAction.none);
      expect(decision.primaryLabel, 'No action');
    });

    test('connecting state with stale runtime recommends troubleshooting', () {
      final decision = RecoveryLadderPolicy.resolve(
        input: RecoveryLadderPolicyInput(
          status: _status(
            phase: ClientConnectionPhase.connecting,
            message: 'Connection attempt is running',
          ),
          readinessReport: null,
          failureFamily: FailureFamily.unknown,
          runtimePosture: _posture(),
          runtimeSession: _session(
            isRunning: true,
            phase: ControllerRuntimePhase.alive,
            age: const Duration(minutes: 2),
          ),
          recentAction: RecoveryRecentActionContext.connectAttempted,
          troubleshootingAvailable: true,
          settingsAvailable: true,
        ),
      );

      expect(decision.primaryAction, RecoveryLadderAction.openTroubleshooting);
      expect(decision.primaryLabel, 'Open Troubleshooting');
      expect(decision.detail, contains('revalidate'));
    });
  });
}
