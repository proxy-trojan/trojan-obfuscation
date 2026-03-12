class ControllerRuntimeConfig {
  const ControllerRuntimeConfig({
    required this.mode,
    required this.endpointHint,
    required this.enableVerboseTelemetry,
  });

  final String mode;
  final String endpointHint;
  final bool enableVerboseTelemetry;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'mode': mode,
      'endpointHint': endpointHint,
      'enableVerboseTelemetry': enableVerboseTelemetry,
    };
  }
}
