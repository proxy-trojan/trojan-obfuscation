import '../domain/routing_probe_models.dart';

enum RoutingProbeVerdictStatus { pass, fail, notApplicable }

class RoutingProbeCaseVerdict {
  const RoutingProbeCaseVerdict({
    required this.status,
    required this.reason,
  });

  final RoutingProbeVerdictStatus status;
  final String reason;
}

class RoutingProbeVerdictService {
  const RoutingProbeVerdictService();

  RoutingProbeCaseVerdict evaluateSingle(RoutingProbeEvidenceRecord record) {
    if (record.errorType == RoutingProbeErrorType.platformCapabilityGap) {
      return const RoutingProbeCaseVerdict(
        status: RoutingProbeVerdictStatus.notApplicable,
        reason: 'platform capability gap',
      );
    }

    if (record.errorType == RoutingProbeErrorType.decisionMismatch ||
        record.errorType == RoutingProbeErrorType.observationMismatch ||
        record.errorType == RoutingProbeErrorType.controllerFailure ||
        record.errorType == RoutingProbeErrorType.probeExecutionFailure ||
        record.errorType == RoutingProbeErrorType.exportFailure) {
      return RoutingProbeCaseVerdict(
        status: RoutingProbeVerdictStatus.fail,
        reason: record.errorDetail,
      );
    }

    return const RoutingProbeCaseVerdict(
      status: RoutingProbeVerdictStatus.pass,
      reason: 'matched expectation',
    );
  }
}
