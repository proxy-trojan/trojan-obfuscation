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
  });

  final ClientConnectionPhase phase;
  final String message;
  final DateTime updatedAt;
  final String? activeProfileId;
  final String? errorCode;
  final String? failureFamilyHint;

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
    bool clearActiveProfile = false,
    bool clearErrorCode = false,
    bool clearFailureFamilyHint = false,
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
