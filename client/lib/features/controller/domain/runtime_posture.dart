enum RuntimePostureKind {
  runtimeTrue,
  stubFallback,
  stubExplicit,
  stubNonDesktop,
  stubSimulated,
  unknown,
}

enum EvidenceGrade {
  evidenceGrade,
  shellGradeOnly,
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

  EvidenceGrade get evidenceGrade => isRuntimeTrue
      ? EvidenceGrade.evidenceGrade
      : EvidenceGrade.shellGradeOnly;

  String get evidenceGradeLabel => switch (evidenceGrade) {
        EvidenceGrade.evidenceGrade => 'Evidence-grade',
        EvidenceGrade.shellGradeOnly => 'Shell-grade only',
      };

  String get evidenceGradeNote => switch (evidenceGrade) {
        EvidenceGrade.evidenceGrade =>
          'Artifacts from this path can be treated as runtime-true execution evidence on this device.',
        EvidenceGrade.shellGradeOnly =>
          'Artifacts from this path are useful for shell/support debugging, but they do not prove real runtime execution.',
      };

  bool get canProduceRuntimeProofArtifact =>
      evidenceGrade == EvidenceGrade.evidenceGrade;

  String get artifactCapabilityLabel => canProduceRuntimeProofArtifact
      ? 'Runtime-proof artifact available'
      : 'Runtime-proof artifact unavailable on current posture';

  String get artifactCapabilityNote => canProduceRuntimeProofArtifact
      ? 'Problem Report exports from this posture can be treated as runtime-proof artifacts on this device.'
      : 'Problem Report exports from this posture should be treated as support bundles only.';

  String get operatorGuidanceHeading => canProduceRuntimeProofArtifact
      ? 'How to use runtime-proof artifacts'
      : 'How to use support bundles on this posture';

  List<String> get operatorChecklist => canProduceRuntimeProofArtifact
      ? const <String>[
          'Verify the posture stays Runtime-true / Evidence-grade before sharing the artifact.',
          'Use the runtime-proof artifact when you need to justify real runtime execution on this device.',
          'Attach the support bundle as extra context, not as a replacement for the proof artifact.',
        ]
      : const <String>[
          'Use this export as a support/debug snapshot only.',
          'Do not cite this posture as runtime-proof execution evidence.',
          'Promote the runtime posture to Evidence-grade before generating proof-oriented artifacts.',
        ];

  String get actionQualifier => switch (kind) {
        RuntimePostureKind.runtimeTrue => '',
        RuntimePostureKind.stubFallback => ' (fallback stub)',
        RuntimePostureKind.stubExplicit => ' (stub path)',
        RuntimePostureKind.stubNonDesktop => ' (non-desktop stub)',
        RuntimePostureKind.stubSimulated => ' (stub path)',
        RuntimePostureKind.unknown => ' (unknown path)',
      };

  String qualifyAction(String baseLabel) {
    final qualifier = actionQualifier;
    return qualifier.isEmpty ? baseLabel : '$baseLabel$qualifier';
  }
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
