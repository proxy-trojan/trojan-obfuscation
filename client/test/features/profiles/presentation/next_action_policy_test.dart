import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/controller/domain/client_connection_status.dart';
import 'package:trojan_pro_client/features/controller/domain/failure_family.dart';
import 'package:trojan_pro_client/features/profiles/presentation/next_action_policy.dart';
import 'package:trojan_pro_client/features/readiness/domain/readiness_report.dart';

void main() {
  group('ProfileNextActionPolicy', () {
    test('maps readiness blocked password to set password action', () {
      final decision = ProfileNextActionPolicy.resolve(
        status: ClientConnectionStatus.disconnected(),
        readinessReport: ReadinessReport.fromChecks(
          const <ReadinessCheck>[
            ReadinessCheck(
              domain: ReadinessDomain.password,
              level: ReadinessLevel.blocked,
              summary: 'Trojan password missing',
              detail: 'Store the Trojan password before connect test.',
            ),
          ],
          generatedAt: DateTime.parse('2026-04-20T01:00:00.000Z'),
        ),
        failureFamily: FailureFamily.unknown,
        troubleshootingAvailable: true,
        settingsAvailable: true,
      );

      expect(decision.type, ProfileNextActionType.openProfiles);
      expect(decision.label, 'Set Password');
      expect(decision.detail, contains('password'));
    });

    test('maps readiness blocked environment to troubleshooting', () {
      final decision = ProfileNextActionPolicy.resolve(
        status: ClientConnectionStatus.disconnected(),
        readinessReport: ReadinessReport.fromChecks(
          const <ReadinessCheck>[
            ReadinessCheck(
              domain: ReadinessDomain.runtimeBinary,
              level: ReadinessLevel.blocked,
              summary: 'runtime binary missing',
              detail: 'Runtime binary could not be found.',
            ),
          ],
          generatedAt: DateTime.parse('2026-04-20T01:00:00.000Z'),
        ),
        failureFamily: FailureFamily.unknown,
        troubleshootingAvailable: true,
        settingsAvailable: false,
      );

      expect(decision.type, ProfileNextActionType.openTroubleshooting);
      expect(decision.label, 'Open Troubleshooting');
    });

    test('maps connect failure family to retry action', () {
      final decision = ProfileNextActionPolicy.resolve(
        status: ClientConnectionStatus(
          phase: ClientConnectionPhase.error,
          message: 'Runtime session exited with code 7.',
          updatedAt: DateTime.parse('2026-04-20T01:00:00.000Z'),
          errorCode: 'RUNTIME_SESSION_EXIT_NONZERO',
          failureFamilyHint: 'connect',
        ),
        readinessReport: null,
        failureFamily: FailureFamily.connect,
        troubleshootingAvailable: true,
        settingsAvailable: true,
      );

      expect(decision.type, ProfileNextActionType.retryConnect);
      expect(decision.label, 'Retry Connect Test');
    });

    test('maps export_os failure family to export support bundle action', () {
      final decision = ProfileNextActionPolicy.resolve(
        status: ClientConnectionStatus(
          phase: ClientConnectionPhase.error,
          message: 'Diagnostics export failed: permission denied.',
          updatedAt: DateTime.parse('2026-04-20T01:00:00.000Z'),
          errorCode: 'DIAGNOSTICS_EXPORT_FAILED',
          failureFamilyHint: 'export_os',
        ),
        readinessReport: null,
        failureFamily: FailureFamily.exportOs,
        troubleshootingAvailable: true,
        settingsAvailable: true,
      );

      expect(decision.type, ProfileNextActionType.exportSupportBundle);
      expect(decision.label, 'Export Support Bundle');
      expect(decision.detail, contains('permissions'));
    });

    test('maps launch failure family to retry action', () {
      final decision = ProfileNextActionPolicy.resolve(
        status: ClientConnectionStatus(
          phase: ClientConnectionPhase.error,
          message: 'Runtime launch failed before session ready.',
          updatedAt: DateTime.parse('2026-04-20T01:00:00.000Z'),
          errorCode: 'RUNTIME_LAUNCH_FAILED',
          failureFamilyHint: 'launch',
        ),
        readinessReport: null,
        failureFamily: FailureFamily.launch,
        troubleshootingAvailable: true,
        settingsAvailable: true,
      );

      expect(decision.type, ProfileNextActionType.retryConnect);
      expect(decision.label, 'Retry Connect Test');
    });

    test('maps config failure family to open profiles action', () {
      final decision = ProfileNextActionPolicy.resolve(
        status: ClientConnectionStatus(
          phase: ClientConnectionPhase.error,
          message: 'Invalid profile field: server port out of range.',
          updatedAt: DateTime.parse('2026-04-20T01:00:00.000Z'),
          errorCode: 'CONFIG_INVALID',
          failureFamilyHint: 'config',
        ),
        readinessReport: null,
        failureFamily: FailureFamily.config,
        troubleshootingAvailable: true,
        settingsAvailable: true,
      );

      expect(decision.type, ProfileNextActionType.openProfiles);
      expect(decision.label, 'Open Profiles');
      expect(decision.detail, contains('config'));
    });

    test('maps environment failure family to settings as primary', () {
      final decision = ProfileNextActionPolicy.resolve(
        status: ClientConnectionStatus(
          phase: ClientConnectionPhase.error,
          message: 'Runtime environment check failed.',
          updatedAt: DateTime.parse('2026-04-20T01:00:00.000Z'),
          errorCode: 'RUNTIME_BINARY_MISSING',
          failureFamilyHint: 'environment',
        ),
        readinessReport: null,
        failureFamily: FailureFamily.environment,
        troubleshootingAvailable: true,
        settingsAvailable: true,
      );

      expect(decision.type, ProfileNextActionType.openSettings);
      expect(decision.label, 'Open Settings');
      expect(decision.detail, contains('environment'));
    });

    test(
        'maps environment failure family to troubleshooting fallback when settings unavailable',
        () {
      final decision = ProfileNextActionPolicy.resolve(
        status: ClientConnectionStatus(
          phase: ClientConnectionPhase.error,
          message: 'Runtime environment check failed.',
          updatedAt: DateTime.parse('2026-04-20T01:00:00.000Z'),
          errorCode: 'RUNTIME_BINARY_MISSING',
          failureFamilyHint: 'environment',
        ),
        readinessReport: null,
        failureFamily: FailureFamily.environment,
        troubleshootingAvailable: true,
        settingsAvailable: false,
      );

      expect(decision.type, ProfileNextActionType.openTroubleshooting);
      expect(decision.label, 'Open Troubleshooting');
    });

    test('unknown failure defaults to evidence-preserving troubleshooting path',
        () {
      final decision = ProfileNextActionPolicy.resolve(
        status: ClientConnectionStatus(
          phase: ClientConnectionPhase.error,
          message: 'Unexpected runtime handshake mismatch.',
          updatedAt: DateTime.parse('2026-04-20T01:00:00.000Z'),
          errorCode: 'UNCLASSIFIED_RUNTIME_FAILURE',
          failureFamilyHint: 'unknown',
        ),
        readinessReport: null,
        failureFamily: FailureFamily.unknown,
        troubleshootingAvailable: true,
        settingsAvailable: true,
      );

      expect(decision.type, ProfileNextActionType.openTroubleshooting);
      expect(decision.label, 'Open Troubleshooting');
      expect(decision.detail, contains('capture runtime evidence'));
    });

    test(
        'unknown failure falls back to profiles when troubleshooting unavailable',
        () {
      final decision = ProfileNextActionPolicy.resolve(
        status: ClientConnectionStatus(
          phase: ClientConnectionPhase.error,
          message: 'Unexpected runtime handshake mismatch.',
          updatedAt: DateTime.parse('2026-04-20T01:00:00.000Z'),
          errorCode: 'UNCLASSIFIED_RUNTIME_FAILURE',
          failureFamilyHint: 'unknown',
        ),
        readinessReport: null,
        failureFamily: FailureFamily.unknown,
        troubleshootingAvailable: false,
        settingsAvailable: true,
      );

      expect(decision.type, ProfileNextActionType.openProfiles);
      expect(decision.label, 'Open Profiles');
      expect(decision.detail, contains('capture runtime evidence'));
    });

    test('maps user_input failure family to set password action', () {
      final decision = ProfileNextActionPolicy.resolve(
        status: ClientConnectionStatus(
          phase: ClientConnectionPhase.error,
          message: 'Trojan password missing.',
          updatedAt: DateTime.parse('2026-04-20T01:00:00.000Z'),
          errorCode: 'MISSING_TROJAN_PASSWORD',
          failureFamilyHint: 'user_input',
        ),
        readinessReport: null,
        failureFamily: FailureFamily.userInput,
        troubleshootingAvailable: true,
        settingsAvailable: true,
      );

      expect(decision.type, ProfileNextActionType.openProfiles);
      expect(decision.label, 'Set Password');
    });

    test('disconnecting prefers troubleshooting by default', () {
      final decision = ProfileNextActionPolicy.resolve(
        status: ClientConnectionStatus(
          phase: ClientConnectionPhase.disconnecting,
          message: 'Disconnecting current session...',
          updatedAt: DateTime.parse('2026-04-20T01:00:00.000Z'),
          activeProfileId: 'sample-hk-1',
        ),
        readinessReport: null,
        failureFamily: FailureFamily.unknown,
        troubleshootingAvailable: true,
        settingsAvailable: false,
      );

      expect(decision.type, ProfileNextActionType.openTroubleshooting);
      expect(decision.label, 'Open Troubleshooting');
      expect(decision.detail, contains('exit confirmation'));
    });
  });
}
