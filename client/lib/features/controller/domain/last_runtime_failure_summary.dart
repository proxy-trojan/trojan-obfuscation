class LastRuntimeFailureSummary {
  const LastRuntimeFailureSummary({
    required this.profileId,
    required this.phase,
    required this.headline,
    required this.detail,
    required this.recordedAt,
  });

  final String? profileId;
  final String phase;
  final String headline;
  final String detail;
  final DateTime recordedAt;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'profileId': profileId,
      'phase': phase,
      'headline': headline,
      'detail': detail,
      'recordedAt': recordedAt.toIso8601String(),
    };
  }

  static LastRuntimeFailureSummary? fromJson(Object? value) {
    if (value is! Map) return null;
    final profileId = value['profileId'];
    final phase = value['phase'];
    final headline = value['headline'];
    final detail = value['detail'];
    final recordedAt = value['recordedAt'];
    if (phase is! String ||
        headline is! String ||
        detail is! String ||
        recordedAt is! String) {
      return null;
    }

    final parsedRecordedAt = DateTime.tryParse(recordedAt);
    if (parsedRecordedAt == null) return null;

    return LastRuntimeFailureSummary(
      profileId: profileId is String ? profileId : null,
      phase: phase,
      headline: headline,
      detail: detail,
      recordedAt: parsedRecordedAt,
    );
  }
}
