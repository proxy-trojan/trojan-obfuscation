class UxEvent {
  const UxEvent({
    required this.userId,
    required this.name,
    required this.at,
    this.sessionId,
    this.fields = const <String, Object?>{},
  });

  final String userId;
  final String name;
  final DateTime at;
  final String? sessionId;
  final Map<String, Object?> fields;
}

class RatioMetric {
  const RatioMetric({required this.numerator, required this.denominator})
      : value = denominator == 0 ? 0 : numerator / denominator;

  final int numerator;
  final int denominator;
  final double value;
}

class HfeMetric {
  const HfeMetric({
    required this.tActionSeconds,
    required this.nSteps,
    required this.rRework,
    required this.index,
  });

  final double tActionSeconds;
  final double nSteps;
  final double rRework;
  final double index;
}
