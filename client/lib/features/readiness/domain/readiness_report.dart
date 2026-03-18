enum ReadinessLevel {
  ready,
  degraded,
  blocked,
}

extension ReadinessLevelLabel on ReadinessLevel {
  String get label => switch (this) {
        ReadinessLevel.ready => 'Ready',
        ReadinessLevel.degraded => 'Ready with warnings',
        ReadinessLevel.blocked => 'Blocked',
      };
}

enum ReadinessDomain {
  profile,
  password,
  secureStorage,
  environment,
  config,
  runtimePath,
  runtimeBinary,
  filesystem,
}

enum ReadinessAction {
  openProfiles,
  openTroubleshooting,
  openSettings,
}

class ReadinessCheck {
  const ReadinessCheck({
    required this.domain,
    required this.level,
    required this.summary,
    this.detail,
    this.action,
    this.actionLabel,
  });

  final ReadinessDomain domain;
  final ReadinessLevel level;
  final String summary;
  final String? detail;
  final ReadinessAction? action;
  final String? actionLabel;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'domain': domain.name,
      'level': level.name,
      'summary': summary,
      'detail': detail,
      'action': action?.name,
      'actionLabel': actionLabel,
    };
  }
}

class ReadinessRecommendation {
  const ReadinessRecommendation({
    required this.action,
    required this.label,
    required this.detail,
  });

  final ReadinessAction action;
  final String label;
  final String detail;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'action': action.name,
      'label': label,
      'detail': detail,
    };
  }
}

class ReadinessReport {
  const ReadinessReport({
    required this.overallLevel,
    required this.checks,
    required this.generatedAt,
  });

  final ReadinessLevel overallLevel;
  final List<ReadinessCheck> checks;
  final DateTime generatedAt;

  static ReadinessReport fromChecks(List<ReadinessCheck> checks) {
    final overall = _calculateOverallLevel(checks);
    return ReadinessReport(
      overallLevel: overall,
      checks: List<ReadinessCheck>.unmodifiable(checks),
      generatedAt: DateTime.now(),
    );
  }

  ReadinessRecommendation? get recommendation {
    final candidate = checks.firstWhere(
      (check) =>
          check.level == ReadinessLevel.blocked &&
          check.action != null &&
          check.actionLabel != null,
      orElse: () => const ReadinessCheck(
        domain: ReadinessDomain.profile,
        level: ReadinessLevel.ready,
        summary: '',
      ),
    );
    if (candidate.action == null || candidate.actionLabel == null) {
      return null;
    }
    return ReadinessRecommendation(
      action: candidate.action!,
      label: candidate.actionLabel!,
      detail: candidate.detail ?? candidate.summary,
    );
  }

  String get headline => switch (overallLevel) {
        ReadinessLevel.blocked => 'Connect blocked',
        ReadinessLevel.degraded => 'Ready with warnings',
        ReadinessLevel.ready => 'Ready for a quick test',
      };

  String get summary {
    final blocked = checks.where((check) => check.level == ReadinessLevel.blocked);
    if (blocked.isNotEmpty) {
      return blocked.first.detail ?? blocked.first.summary;
    }
    final degraded =
        checks.where((check) => check.level == ReadinessLevel.degraded);
    if (degraded.isNotEmpty) {
      return degraded.first.detail ?? degraded.first.summary;
    }
    return 'All readiness checks look healthy.';
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'overallLevel': overallLevel.name,
      'headline': headline,
      'summary': summary,
      'generatedAt': generatedAt.toIso8601String(),
      'checks': checks.map((check) => check.toJson()).toList(),
      'recommendation': recommendation?.toJson(),
    };
  }

  static ReadinessLevel _calculateOverallLevel(List<ReadinessCheck> checks) {
    if (checks.any((check) => check.level == ReadinessLevel.blocked)) {
      return ReadinessLevel.blocked;
    }
    if (checks.any((check) => check.level == ReadinessLevel.degraded)) {
      return ReadinessLevel.degraded;
    }
    return ReadinessLevel.ready;
  }
}
