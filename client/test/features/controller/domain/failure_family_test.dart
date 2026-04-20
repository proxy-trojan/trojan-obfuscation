import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/controller/domain/failure_family.dart';

void main() {
  group('classifyFailureFamily', () {
    test('prioritizes structured errorCode over free-form summary/detail', () {
      final family = classifyFailureFamily(
        errorCode: 'MISSING_TROJAN_PASSWORD',
        summary: 'config invalid for runtime launch',
        detail: 'runtime session exited with code 7',
        phase: 'runtime',
      );

      expect(family, FailureFamily.userInput);
    });

    test('maps key structured error codes to expected families', () {
      expect(
        classifyFailureFamily(errorCode: 'MISSING_TROJAN_PASSWORD'),
        FailureFamily.userInput,
      );
      expect(
        classifyFailureFamily(errorCode: 'CONFIG_INVALID_FOR_RUNTIME_LAUNCH'),
        FailureFamily.config,
      );
      expect(
        classifyFailureFamily(errorCode: 'UNSUPPORTED'),
        FailureFamily.environment,
      );
      expect(
        classifyFailureFamily(errorCode: 'RUNTIME_SESSION_EXIT_NONZERO'),
        FailureFamily.connect,
      );
      expect(
        classifyFailureFamily(errorCode: 'DIAGNOSTICS_EXPORT_FAILED'),
        FailureFamily.exportOs,
      );
      expect(
        classifyFailureFamily(errorCode: 'PROCESS_ALREADY_RUNNING'),
        FailureFamily.launch,
      );
    });

    test('uses phase as fallback when no structured mapping is available', () {
      expect(
        classifyFailureFamily(
          errorCode: 'SOMETHING_UNMAPPED',
          phase: 'launch',
        ),
        FailureFamily.launch,
      );
      expect(
        classifyFailureFamily(
          errorCode: 'SOMETHING_UNMAPPED',
          phase: 'config',
        ),
        FailureFamily.config,
      );
      expect(
        classifyFailureFamily(
          errorCode: 'SOMETHING_UNMAPPED',
          phase: 'runtime',
        ),
        FailureFamily.connect,
      );
      expect(
        classifyFailureFamily(
          errorCode: 'SOMETHING_UNMAPPED',
          phase: 'environment',
        ),
        FailureFamily.environment,
      );
      expect(
        classifyFailureFamily(
          errorCode: 'SOMETHING_UNMAPPED',
          phase: 'export',
        ),
        FailureFamily.exportOs,
      );
      expect(
        classifyFailureFamily(
          errorCode: 'SOMETHING_UNMAPPED',
          phase: 'user_input',
        ),
        FailureFamily.userInput,
      );
    });

    test('keeps backward compatibility for legacy free-form inference', () {
      expect(
        classifyFailureFamily(
          summary: 'permission denied for diagnostics export',
        ),
        FailureFamily.exportOs,
      );
      expect(
        classifyFailureFamily(
          summary: 'runtime session exited with code 9',
        ),
        FailureFamily.connect,
      );
      expect(
        classifyFailureFamily(
          summary: 'failed to execute trojan client launch plan',
        ),
        FailureFamily.launch,
      );
      expect(
        classifyFailureFamily(
          summary: 'config preparation failed',
        ),
        FailureFamily.config,
      );
    });

    test('returns unknown when no structured/fallback signal exists', () {
      expect(
        classifyFailureFamily(
          errorCode: 'SOMETHING_UNMAPPED',
          summary: 'totally generic failure text',
        ),
        FailureFamily.unknown,
      );
    });
  });
}
