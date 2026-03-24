import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/controller/domain/runtime_posture.dart';

void main() {
  test('describes runtime-true posture', () {
    final posture = describeRuntimePosture(
      runtimeMode: 'real-runtime-boundary',
      backendKind: 'real-shell-controller',
    );

    expect(posture.kind, RuntimePostureKind.runtimeTrue);
    expect(posture.isRuntimeTrue, isTrue);
    expect(posture.postureLabel, 'Runtime-true');
    expect(posture.evidenceGradeLabel, 'Evidence-grade');
    expect(posture.executionPathLabel, 'Real runtime path');
  });

  test('describes fallback stub posture', () {
    final posture = describeRuntimePosture(
      runtimeMode: 'stubbed-local-boundary-fallback',
      backendKind: 'fake-shell-controller-fallback',
    );

    expect(posture.kind, RuntimePostureKind.stubFallback);
    expect(posture.isStubOnly, isTrue);
    expect(posture.postureLabel, 'Stub-only (fallback)');
    expect(posture.evidenceGradeLabel, 'Shell-grade only');
    expect(
      posture.truthNote,
      contains('fell back to a stub boundary'),
    );
  });

  test('describes non-desktop stub posture', () {
    final posture = describeRuntimePosture(
      runtimeMode: 'stubbed-local-boundary-non-desktop',
      backendKind: 'fake-shell-controller-non-desktop',
    );

    expect(posture.kind, RuntimePostureKind.stubNonDesktop);
    expect(posture.postureLabel, 'Stub-only (non-desktop)');
    expect(posture.executionPathLabel, 'Stub mode (non-desktop target)');
  });

  test('keeps unknown posture explicit', () {
    final posture = describeRuntimePosture(
      runtimeMode: 'mystery-runtime-mode',
      backendKind: 'mystery-backend',
    );

    expect(posture.kind, RuntimePostureKind.unknown);
    expect(posture.postureLabel, 'Unknown posture');
    expect(posture.truthNote, contains('not recognized'));
  });
}
