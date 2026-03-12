enum ControllerRuntimeHealthLevel {
  healthy,
  degraded,
  unavailable,
}

class ControllerRuntimeHealth {
  const ControllerRuntimeHealth({
    required this.level,
    required this.summary,
    required this.updatedAt,
  });

  final ControllerRuntimeHealthLevel level;
  final String summary;
  final DateTime updatedAt;
}
