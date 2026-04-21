import '../domain/ux_metric_models.dart';

class UxMetricService {
  RatioMetric computeFcsr(List<UxEvent> events) {
    final started = events
        .where((event) => event.name == 'first_session_started')
        .map((event) => event.userId)
        .toSet();

    final success = events
        .where((event) => event.name == 'runtime_session_ready_runtime_true')
        .map((event) => event.userId)
        .where(started.contains)
        .toSet();

    return RatioMetric(
      numerator: success.length,
      denominator: started.length,
    );
  }

  HfeMetric computeHfe(List<UxEvent> events) {
    final actionDurations = <double>[];
    final actionSteps = <double>[];

    for (final complete in events.where((event) => event.name == 'action_completed')) {
      final actionType = complete.fields['actionType'] as String?;
      final intentName = switch (actionType) {
        'connect' => 'quick_connect_clicked',
        'disconnect' => 'quick_disconnect_clicked',
        'switch_profile' => 'profile_switched',
        _ => null,
      };
      if (intentName == null) {
        continue;
      }

      final candidates = events.where((event) {
        if (event.name != intentName) return false;
        if (event.userId != complete.userId) return false;
        if (complete.sessionId != null && event.sessionId != complete.sessionId) {
          return false;
        }
        return !event.at.isAfter(complete.at);
      }).toList()
        ..sort((left, right) => right.at.compareTo(left.at));

      if (candidates.isNotEmpty) {
        final seconds = complete.at.difference(candidates.first.at).inMilliseconds / 1000;
        actionDurations.add(seconds);
      }

      final steps = complete.fields['interactionSteps'];
      if (steps is num) {
        actionSteps.add(steps.toDouble());
      }
    }

    final completedCount = events.where((event) => event.name == 'action_completed').length;
    final reworkCount = events.where((event) => event.name == 'action_rework_detected').length;

    final tAction = _median(actionDurations);
    final nSteps = _median(actionSteps);
    final rRework = completedCount == 0 ? 0.0 : reworkCount / completedCount;

    final tNorm = _normalize(tAction, min: 0.0, max: 12.0);
    final nNorm = _normalize(nSteps, min: 0.0, max: 4.0);
    final rNorm = _normalize(rRework, min: 0.0, max: 1.0);

    return HfeMetric(
      tActionSeconds: tAction,
      nSteps: nSteps,
      rRework: rRework,
      index: 0.5 * tNorm + 0.3 * nNorm + 0.2 * rNorm,
    );
  }

  RatioMetric computeSsr(List<UxEvent> events) {
    final suggestedSessions = events
        .where((event) => event.name == 'recovery_suggested')
        .map((event) => event.sessionId)
        .whereType<String>()
        .toSet();

    final successSessions = events
        .where((event) => event.name == 'recovery_outcome')
        .where((event) => event.fields['outcome'] == 'success')
        .map((event) => event.sessionId)
        .whereType<String>()
        .where(suggestedSessions.contains)
        .toSet();

    return RatioMetric(
      numerator: successSessions.length,
      denominator: suggestedSessions.length,
    );
  }

  RatioMetric computeSte(List<UxEvent> events) {
    final completed = events
        .where((event) => event.name == 'diagnostics_export_completed')
        .toList();

    final qualifying = completed.where((event) {
      final hasRuntimePosture = event.fields.containsKey('runtimePosture');
      final hasRecoveryEvidence = event.fields.containsKey('includesRecoveryEvidence');
      return hasRuntimePosture && hasRecoveryEvidence;
    }).length;

    return RatioMetric(
      numerator: qualifying,
      denominator: completed.length,
    );
  }

  double _median(List<double> values) {
    if (values.isEmpty) {
      return 0.0;
    }
    final sorted = values.toList()..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) {
      return sorted[mid];
    }
    return (sorted[mid - 1] + sorted[mid]) / 2;
  }

  double _normalize(double value, {required double min, required double max}) {
    if (max <= min) {
      return 0.0;
    }
    final normalized = (value - min) / (max - min);
    if (normalized < 0) return 0.0;
    if (normalized > 1) return 1.0;
    return normalized;
  }
}
