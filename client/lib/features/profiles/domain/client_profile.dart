class ClientProfile {
  const ClientProfile({
    required this.id,
    required this.name,
    required this.serverHost,
    required this.serverPort,
    required this.sni,
    required this.localSocksPort,
    required this.verifyTls,
    required this.updatedAt,
    this.notes = '',
    this.hasStoredPassword = false,
  });

  final String id;
  final String name;
  final String serverHost;
  final int serverPort;
  final String sni;
  final int localSocksPort;
  final bool verifyTls;
  final String notes;
  final DateTime updatedAt;
  final bool hasStoredPassword;

  ClientProfile copyWith({
    String? id,
    String? name,
    String? serverHost,
    int? serverPort,
    String? sni,
    int? localSocksPort,
    bool? verifyTls,
    String? notes,
    DateTime? updatedAt,
    bool? hasStoredPassword,
  }) {
    return ClientProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      serverHost: serverHost ?? this.serverHost,
      serverPort: serverPort ?? this.serverPort,
      sni: sni ?? this.sni,
      localSocksPort: localSocksPort ?? this.localSocksPort,
      verifyTls: verifyTls ?? this.verifyTls,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
      hasStoredPassword: hasStoredPassword ?? this.hasStoredPassword,
    );
  }
}
