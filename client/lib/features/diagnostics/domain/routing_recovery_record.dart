class RoutingRecoveryRecord {
  const RoutingRecoveryRecord({
    required this.operationId,
    required this.profileId,
    required this.rollbackReason,
    required this.safeModeActivated,
    required this.quarantined,
    required this.timestamp,
    this.quarantineKey,
  });

  final String operationId;
  final String profileId;
  final String rollbackReason;
  final bool safeModeActivated;
  final bool quarantined;
  final DateTime timestamp;
  final String? quarantineKey;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'operationId': operationId,
      'profileId': profileId,
      'rollbackReason': rollbackReason,
      'safeModeActivated': safeModeActivated,
      'quarantined': quarantined,
      'quarantineKey': quarantineKey,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
