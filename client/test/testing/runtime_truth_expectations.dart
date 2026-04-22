import 'package:trojan_pro_client/features/controller/domain/controller_runtime_session.dart';

/// Shared expectations for runtime truth messaging.
///
/// Iter-3 requires cross-surface truth consistency. Widget/domain tests should
/// prefer these expectations over hard-coded strings to reduce future drift.
class RuntimeTruthExpectation {
  const RuntimeTruthExpectation({
    required this.truth,
    required this.label,
    required this.needsAttention,
    required this.truthNoteContains,
    required this.recoveryGuidanceContains,
  });

  final ControllerRuntimeSessionTruth truth;
  final String label;
  final bool needsAttention;
  final List<String> truthNoteContains;
  final List<String> recoveryGuidanceContains;
}

/// Iter-3 truth states that must stay consistent across product surfaces.
const List<ControllerRuntimeSessionTruth> iter3TruthStates =
    <ControllerRuntimeSessionTruth>[
  ControllerRuntimeSessionTruth.live,
  ControllerRuntimeSessionTruth.aging,
  ControllerRuntimeSessionTruth.stale,
  ControllerRuntimeSessionTruth.residual,
  ControllerRuntimeSessionTruth.stopping,
];

const Map<ControllerRuntimeSessionTruth, RuntimeTruthExpectation>
    runtimeTruthExpectations =
    <ControllerRuntimeSessionTruth, RuntimeTruthExpectation>{
  ControllerRuntimeSessionTruth.live: RuntimeTruthExpectation(
    truth: ControllerRuntimeSessionTruth.live,
    label: 'Live',
    needsAttention: false,
    truthNoteContains: <String>[
      'recently refreshed',
    ],
    recoveryGuidanceContains: <String>[
      'No recovery action',
    ],
  ),
  ControllerRuntimeSessionTruth.aging: RuntimeTruthExpectation(
    truth: ControllerRuntimeSessionTruth.aging,
    label: 'Aging',
    needsAttention: true,
    truthNoteContains: <String>[
      'getting older',
    ],
    recoveryGuidanceContains: <String>[
      'open Troubleshooting',
    ],
  ),
  ControllerRuntimeSessionTruth.stale: RuntimeTruthExpectation(
    truth: ControllerRuntimeSessionTruth.stale,
    label: 'Stale',
    needsAttention: true,
    truthNoteContains: <String>[
      'stale',
    ],
    recoveryGuidanceContains: <String>[
      'revalidate',
      'disconnect and reconnect',
    ],
  ),
  ControllerRuntimeSessionTruth.residual: RuntimeTruthExpectation(
    truth: ControllerRuntimeSessionTruth.residual,
    label: 'Residual snapshot',
    needsAttention: true,
    truthNoteContains: <String>[
      'residual state',
    ],
    recoveryGuidanceContains: <String>[
      'leftover session state',
      'retry from Profiles',
    ],
  ),
  ControllerRuntimeSessionTruth.stopping: RuntimeTruthExpectation(
    truth: ControllerRuntimeSessionTruth.stopping,
    label: 'Stopping',
    needsAttention: true,
    truthNoteContains: <String>[
      'exit confirmation',
    ],
    recoveryGuidanceContains: <String>[
      'exit confirmation',
    ],
  ),
};

RuntimeTruthExpectation runtimeTruthExpectationFor(
  ControllerRuntimeSessionTruth truth,
) {
  return runtimeTruthExpectations[truth]!;
}

ControllerRuntimeSession buildSessionForTruth(
  ControllerRuntimeSessionTruth truth,
) {
  final now = DateTime.now();

  return switch (truth) {
    ControllerRuntimeSessionTruth.live => ControllerRuntimeSession(
        isRunning: true,
        updatedAt: now.subtract(const Duration(seconds: 5)),
        phase: ControllerRuntimePhase.sessionReady,
        expectedLocalSocksPort: 10808,
      ),
    ControllerRuntimeSessionTruth.aging => ControllerRuntimeSession(
        isRunning: true,
        updatedAt: now.subtract(const Duration(seconds: 45)),
        phase: ControllerRuntimePhase.sessionReady,
        expectedLocalSocksPort: 10808,
      ),
    ControllerRuntimeSessionTruth.stale => ControllerRuntimeSession(
        isRunning: true,
        updatedAt: now.subtract(const Duration(minutes: 5)),
        phase: ControllerRuntimePhase.sessionReady,
        expectedLocalSocksPort: 10808,
      ),
    ControllerRuntimeSessionTruth.residual => ControllerRuntimeSession(
        isRunning: false,
        updatedAt: now.subtract(const Duration(minutes: 1)),
        phase: ControllerRuntimePhase.sessionReady,
        expectedLocalSocksPort: 10808,
      ),
    ControllerRuntimeSessionTruth.stopping => ControllerRuntimeSession(
        isRunning: true,
        updatedAt: now.subtract(const Duration(seconds: 20)),
        phase: ControllerRuntimePhase.alive,
        stopRequested: true,
        stopRequestedAt: now.subtract(const Duration(seconds: 10)),
        expectedLocalSocksPort: 10808,
      ),
    ControllerRuntimeSessionTruth.stopped => ControllerRuntimeSession(
        isRunning: false,
        updatedAt: now,
        phase: ControllerRuntimePhase.stopped,
      ),
  };
}
