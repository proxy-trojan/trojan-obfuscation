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

  static ReadinessCheck? fromJson(Object? value) {
    if (value is! Map) return null;
    final domain = _enumByName(ReadinessDomain.values, value['domain']);
    final level = _enumByName(ReadinessLevel.values, value['level']);
    final summary = value['summary'];
    if (domain == null || level == null || summary is! String) {
      return null;
    }
    return ReadinessCheck(
      domain: domain,
      level: level,
      summary: summary,
      detail: value['detail'] is String ? value['detail'] as String : null,
      action: _enumByName(ReadinessAction.values, value['action']),
      actionLabel:
          value['actionLabel'] is String ? value['actionLabel'] as String : null,
    );
  }

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

  static ReadinessReport? fromJson(Object? value) {
    if (value is! Map) return null;
    final overallLevel = _enumByName(ReadinessLevel.values, value['overallLevel']);
    final generatedAtRaw = value['generatedAt'];
    final checksRaw = value['checks'];
    if (overallLevel == null ||
        generatedAtRaw is! String ||
        checksRaw is! List) {
      return null;
    }
    final generatedAt = DateTime.tryParse(generatedAtRaw);
    if (generatedAt == null) {
      return null;
    }
    final checks = checksRaw
        .map(ReadinessCheck.fromJson)
        .whereType<ReadinessCheck>()
        .toList();
    return ReadinessReport(
      overallLevel: overallLevel,
      checks: List<ReadinessCheck>.unmodifiable(checks),
      generatedAt: generatedAt,
    );
  }

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
    final candidates = checks
        .where(
          (check) =>
              check.level != ReadinessLevel.ready &&
              check.action != null &&
              check.actionLabel != null,
        )
        .toList()
      ..sort(
        (left, right) =>
            _recommendationPriority(left) - _recommendationPriority(right),
      );

    if (candidates.isEmpty) {
      return null;
    }

    final candidate = candidates.first;
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

  static int _recommendationPriority(ReadinessCheck check) {
    final levelBase = switch (check.level) {
      ReadinessLevel.blocked => 0,
      ReadinessLevel.degraded => 100,
      ReadinessLevel.ready => 1000,
    };
    final domainRank = switch (check.domain) {
      ReadinessDomain.password => 0,
      ReadinessDomain.profile => 1,
      ReadinessDomain.config => 2,
      ReadinessDomain.runtimeBinary => 3,
      ReadinessDomain.filesystem => 4,
      ReadinessDomain.secureStorage => 5,
      ReadinessDomain.runtimePath => 6,
      ReadinessDomain.environment => 7,
    };
    return levelBase + domainRank;
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

T? _enumByName<T extends Enum>(List<T> values, Object? raw) {
  if (raw is! String) return null;
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return null;
}
