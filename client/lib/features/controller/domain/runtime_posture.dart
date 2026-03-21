enum RuntimePostureKind {
  runtimeTrue,
  stubFallback,
  stubExplicit,
  stubNonDesktop,
  stubSimulated,
  unknown,
}

class RuntimePosture {
  const RuntimePosture({
    required this.kind,
    required this.runtimeMode,
    this.backendKind,
  });

  final RuntimePostureKind kind;
  final String runtimeMode;
  final String? backendKind;

  bool get isRuntimeTrue => kind == RuntimePostureKind.runtimeTrue;

  bool get isStubOnly => !isRuntimeTrue;

  String get executionPathLabel => switch (kind) {
        RuntimePostureKind.runtimeTrue => 'Real runtime path',
        RuntimePostureKind.stubFallback =>
          'Fallback stub (real runtime unavailable)',
        RuntimePostureKind.stubExplicit => 'Explicit stub mode',
        RuntimePostureKind.stubNonDesktop => 'Stub mode (non-desktop target)',
        RuntimePostureKind.stubSimulated => 'Simulated runtime path',
        RuntimePostureKind.unknown => 'Unknown runtime path',
      };

  String get postureLabel => switch (kind) {
        RuntimePostureKind.runtimeTrue => 'Runtime-true',
        RuntimePostureKind.stubFallback => 'Stub-only (fallback)',
        RuntimePostureKind.stubExplicit => 'Stub-only (explicit)',
        RuntimePostureKind.stubNonDesktop => 'Stub-only (non-desktop)',
        RuntimePostureKind.stubSimulated => 'Stub-only',
        RuntimePostureKind.unknown => 'Unknown posture',
      };

  String get truthNote => switch (kind) {
        RuntimePostureKind.runtimeTrue =>
          'This path counts as real runtime execution evidence on this device.',
        RuntimePostureKind.stubFallback =>
          'The shell fell back to a stub boundary because the real runtime path is unavailable.',
        RuntimePostureKind.stubExplicit =>
          'Stub mode was selected intentionally for shell/product testing and is not runtime-true evidence.',
        RuntimePostureKind.stubNonDesktop =>
          'This target is staying on a non-desktop stub path and should not be treated as runtime-true execution.',
        RuntimePostureKind.stubSimulated =>
          'This path is simulated and is useful for shell validation, not real runtime proof.',
        RuntimePostureKind.unknown =>
          'The current runtime mode is not recognized by this shell yet.',
      };
}

RuntimePosture describeRuntimePosture({
  required String runtimeMode,
  String? backendKind,
}) {
  if (runtimeMode.contains('real-runtime-boundary')) {
    return RuntimePosture(
      kind: RuntimePostureKind.runtimeTrue,
      runtimeMode: runtimeMode,
      backendKind: backendKind,
    );
  }
  if (runtimeMode.contains('stubbed-local-boundary-fallback')) {
    return RuntimePosture(
      kind: RuntimePostureKind.stubFallback,
      runtimeMode: runtimeMode,
      backendKind: backendKind,
    );
  }
  if (runtimeMode.contains('stubbed-local-boundary-explicit')) {
    return RuntimePosture(
      kind: RuntimePostureKind.stubExplicit,
      runtimeMode: runtimeMode,
      backendKind: backendKind,
    );
  }
  if (runtimeMode.contains('stubbed-local-boundary-non-desktop')) {
    return RuntimePosture(
      kind: RuntimePostureKind.stubNonDesktop,
      runtimeMode: runtimeMode,
      backendKind: backendKind,
    );
  }
  if (runtimeMode.contains('stubbed-local-boundary')) {
    return RuntimePosture(
      kind: RuntimePostureKind.stubSimulated,
      runtimeMode: runtimeMode,
      backendKind: backendKind,
    );
  }
  return RuntimePosture(
    kind: RuntimePostureKind.unknown,
    runtimeMode: runtimeMode,
    backendKind: backendKind,
  );
}
