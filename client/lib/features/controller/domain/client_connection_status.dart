enum ClientConnectionPhase {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error,
}

class ClientConnectionStatus {
  const ClientConnectionStatus({
    required this.phase,
    required this.message,
    required this.updatedAt,
    this.activeProfileId,
    this.errorCode,
    this.failureFamilyHint,
    this.safeModeActive = false,
    this.quarantineKey,
    this.rollbackReason,
  });

  final ClientConnectionPhase phase;
  final String message;
  final DateTime updatedAt;
  final String? activeProfileId;
  final String? errorCode;
  final String? failureFamilyHint;
  final bool safeModeActive;
  final String? quarantineKey;
  final String? rollbackReason;

  bool get isConnected => phase == ClientConnectionPhase.connected;
  bool get isBusy =>
      phase == ClientConnectionPhase.connecting ||
      phase == ClientConnectionPhase.disconnecting;

  ClientConnectionStatus copyWith({
    ClientConnectionPhase? phase,
    String? message,
    DateTime? updatedAt,
    String? activeProfileId,
    String? errorCode,
    String? failureFamilyHint,
    bool? safeModeActive,
    String? quarantineKey,
    String? rollbackReason,
    bool clearActiveProfile = false,
    bool clearErrorCode = false,
    bool clearFailureFamilyHint = false,
    bool clearQuarantineKey = false,
    bool clearRollbackReason = false,
  }) {
    return ClientConnectionStatus(
      phase: phase ?? this.phase,
      message: message ?? this.message,
      updatedAt: updatedAt ?? this.updatedAt,
      activeProfileId:
          clearActiveProfile ? null : (activeProfileId ?? this.activeProfileId),
      errorCode: clearErrorCode ? null : (errorCode ?? this.errorCode),
      failureFamilyHint: clearFailureFamilyHint
          ? null
          : (failureFamilyHint ?? this.failureFamilyHint),
      safeModeActive: safeModeActive ?? this.safeModeActive,
      quarantineKey:
          clearQuarantineKey ? null : (quarantineKey ?? this.quarantineKey),
      rollbackReason:
          clearRollbackReason ? null : (rollbackReason ?? this.rollbackReason),
    );
  }

  static ClientConnectionStatus disconnected() {
    return ClientConnectionStatus(
      phase: ClientConnectionPhase.disconnected,
      message: 'Disconnected',
      updatedAt: DateTime.now(),
    );
  }
}
