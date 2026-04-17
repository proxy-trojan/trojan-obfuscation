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
            'runtimePosture': runtimePosture,
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
            'runtimePosture': runtimePosture,
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
}
