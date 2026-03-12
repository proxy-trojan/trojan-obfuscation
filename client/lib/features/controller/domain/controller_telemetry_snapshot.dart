class ControllerTelemetrySnapshot {
  const ControllerTelemetrySnapshot({
    required this.backendKind,
    required this.backendVersion,
    required this.capabilities,
    required this.lastUpdatedAt,
  });

  final String backendKind;
  final String backendVersion;
  final List<String> capabilities;
  final DateTime lastUpdatedAt;
}
