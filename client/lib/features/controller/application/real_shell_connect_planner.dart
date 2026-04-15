import '../../profiles/domain/client_profile.dart';
import '../../routing/application/routing_profile_codec.dart';
import '../domain/controller_command.dart';

class RealShellConnectPlannerInput {
  const RealShellConnectPlannerInput({
    required this.profile,
    required this.configPath,
    required this.password,
  });

  final ClientProfile profile;
  final String configPath;
  final String password;
}

class RealShellConnectPlanner {
  RealShellConnectPlanner({RoutingProfileCodec? routingCodec})
      : _routingCodec = routingCodec ?? const RoutingProfileCodec();

  final RoutingProfileCodec _routingCodec;

  RealShellConnectPlannerInput? parse(ControllerCommand command) {
    final profileName = command.arguments['profileName'] as String?;
    final serverHost = command.arguments['serverHost'] as String?;
    final serverPort = command.arguments['serverPort'] as int?;
    final localSocksPort = command.arguments['localSocksPort'] as int?;
    final sni = command.arguments['sni'] as String?;
    final verifyTls = command.arguments['verifyTls'] as bool?;
    final configPath = command.arguments['configPath'] as String?;
    final password = command.secretArguments['trojanPassword'];

    if (profileName == null ||
        serverHost == null ||
        serverPort == null ||
        localSocksPort == null ||
        configPath == null ||
        password == null ||
        password.trim().isEmpty) {
      return null;
    }

    return RealShellConnectPlannerInput(
      profile: ClientProfile(
        id: command.profileId ?? 'unknown',
        name: profileName,
        serverHost: serverHost,
        serverPort: serverPort,
        sni: (sni == null || sni.isEmpty) ? serverHost : sni,
        localSocksPort: localSocksPort,
        verifyTls: verifyTls ?? true,
        updatedAt: command.issuedAt,
        routing: _routingCodec.decodeFromObject(command.arguments['routing']),
      ),
      configPath: configPath,
      password: password,
    );
  }
}
