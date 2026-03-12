class ControllerCommandResult {
  const ControllerCommandResult({
    required this.commandId,
    required this.accepted,
    required this.completedAt,
    required this.summary,
    this.error,
    this.details = const <String, Object?>{},
  });

  final String commandId;
  final bool accepted;
  final DateTime completedAt;
  final String summary;
  final String? error;
  final Map<String, Object?> details;
}
