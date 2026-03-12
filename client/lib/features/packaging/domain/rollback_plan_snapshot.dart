class RollbackPlanSnapshot {
  const RollbackPlanSnapshot({
    required this.generatedAt,
    required this.currentVersionLabel,
    required this.channel,
    required this.rollbackArtifactHint,
    required this.steps,
  });

  final DateTime generatedAt;
  final String currentVersionLabel;
  final String channel;
  final String rollbackArtifactHint;
  final List<String> steps;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'generatedAt': generatedAt.toIso8601String(),
      'currentVersionLabel': currentVersionLabel,
      'channel': channel,
      'rollbackArtifactHint': rollbackArtifactHint,
      'steps': steps,
    };
  }
}
