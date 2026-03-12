class UpdateMetadataSnapshot {
  const UpdateMetadataSnapshot({
    required this.generatedAt,
    required this.channel,
    required this.updateChecksEnabled,
    required this.currentVersionLabel,
    required this.manifestArtifactName,
    required this.summary,
  });

  final DateTime generatedAt;
  final String channel;
  final bool updateChecksEnabled;
  final String currentVersionLabel;
  final String manifestArtifactName;
  final String summary;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'generatedAt': generatedAt.toIso8601String(),
      'channel': channel,
      'updateChecksEnabled': updateChecksEnabled,
      'currentVersionLabel': currentVersionLabel,
      'manifestArtifactName': manifestArtifactName,
      'summary': summary,
    };
  }
}
