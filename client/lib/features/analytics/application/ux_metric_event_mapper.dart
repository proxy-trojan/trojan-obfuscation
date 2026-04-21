import '../domain/ux_metric_models.dart';

class UxMetricEventMapper {
  List<UxEvent> fromConnectionSnapshot({
    required String userId,
    required String sessionId,
    required String phase,
    required String runtimePosture,
    required String? failureFamily,
    DateTime? at,
  }) {
    final now = at ?? DateTime.now();
    final output = <UxEvent>[];

    if (phase == 'connecting') {
      output.add(
        UxEvent(
          userId: userId,
          sessionId: sessionId,
          name: 'first_connect_attempted',
          at: now,
          fields: <String, Object?>{
            'runtimePosture': _normalizeRuntimePosture(runtimePosture),
          },
        ),
      );
    }

    if (phase == 'connected' && runtimePosture == 'runtimeTrue') {
      output.add(
        UxEvent(
          userId: userId,
          sessionId: sessionId,
          name: 'runtime_session_ready_runtime_true',
          at: now,
          fields: const <String, Object?>{
            'runtimePosture': 'runtime_true',
          },
        ),
      );
    }

    if (phase == 'error' && failureFamily != null && failureFamily.isNotEmpty) {
      output.add(
        UxEvent(
          userId: userId,
          sessionId: sessionId,
          name: 'connect_failed_$failureFamily',
          at: now,
          fields: <String, Object?>{
            'runtimePosture': _normalizeRuntimePosture(runtimePosture),
            'failureFamily': failureFamily,
          },
        ),
      );
      output.add(
        UxEvent(
          userId: userId,
          sessionId: sessionId,
          name: 'recovery_suggested',
          at: now,
          fields: <String, Object?>{
            'failureFamily': failureFamily,
          },
        ),
      );
    }

    return output;
  }

  UxEvent recoveryActionExecuted({
    required String userId,
    required String sessionId,
    required String action,
    required String source,
    required String failureFamily,
    required String runtimePosture,
    DateTime? at,
  }) {
    return UxEvent(
      userId: userId,
      sessionId: sessionId,
      name: 'recovery_action_executed',
      at: at ?? DateTime.now(),
      fields: <String, Object?>{
        'action': action,
        'source': source,
        'failureFamily': failureFamily,
        'runtimePosture': _normalizeRuntimePosture(runtimePosture),
      },
    );
  }

  UxEvent recoveryOutcome({
    required String userId,
    required String sessionId,
    required String action,
    required String source,
    required String failureFamily,
    required String runtimePosture,
    required String outcome,
    DateTime? at,
  }) {
    return UxEvent(
      userId: userId,
      sessionId: sessionId,
      name: 'recovery_outcome',
      at: at ?? DateTime.now(),
      fields: <String, Object?>{
        'action': action,
        'source': source,
        'failureFamily': failureFamily,
        'runtimePosture': _normalizeRuntimePosture(runtimePosture),
        'outcome': outcome,
      },
    );
  }

  String _normalizeRuntimePosture(String runtimePosture) {
    return switch (runtimePosture) {
      'runtimeTrue' || 'runtime_true' => 'runtime_true',
      'fallbackStub' || 'fallback_stub' => 'fallback',
      'explicitStub' || 'nonDesktopStub' || 'stub' => 'stub',
      _ => runtimePosture,
    };
  }
}
