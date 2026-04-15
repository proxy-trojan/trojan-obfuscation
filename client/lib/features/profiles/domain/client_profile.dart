import '../../routing/domain/routing_profile_config.dart';

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
    this.routing = RoutingProfileConfig.defaults,
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
  final RoutingProfileConfig routing;

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
    RoutingProfileConfig? routing,
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
      routing: routing ?? this.routing,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClientProfile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          serverHost == other.serverHost &&
          serverPort == other.serverPort &&
          sni == other.sni &&
          localSocksPort == other.localSocksPort &&
          verifyTls == other.verifyTls &&
          notes == other.notes &&
          updatedAt == other.updatedAt &&
          hasStoredPassword == other.hasStoredPassword &&
          routing == other.routing;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        serverHost,
        serverPort,
        sni,
        localSocksPort,
        verifyTls,
        notes,
        updatedAt,
        hasStoredPassword,
        routing,
      );
}
