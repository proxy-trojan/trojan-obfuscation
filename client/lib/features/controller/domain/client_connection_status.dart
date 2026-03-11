enum ClientConnectionPhase {
  disconnected,
  connecting,
  connected,
  error,
}

class ClientConnectionStatus {
  const ClientConnectionStatus({
    required this.phase,
    required this.message,
    required this.updatedAt,
    this.activeProfileId,
  });

  final ClientConnectionPhase phase;
  final String message;
  final DateTime updatedAt;
  final String? activeProfileId;

  bool get isConnected => phase == ClientConnectionPhase.connected;
  bool get isBusy => phase == ClientConnectionPhase.connecting;

  ClientConnectionStatus copyWith({
    ClientConnectionPhase? phase,
    String? message,
    DateTime? updatedAt,
    String? activeProfileId,
    bool clearActiveProfile = false,
  }) {
    return ClientConnectionStatus(
      phase: phase ?? this.phase,
      message: message ?? this.message,
      updatedAt: updatedAt ?? this.updatedAt,
      activeProfileId:
          clearActiveProfile ? null : (activeProfileId ?? this.activeProfileId),
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
