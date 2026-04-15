import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/controller/application/real_shell_connect_planner.dart';
import 'package:trojan_pro_client/features/controller/domain/controller_command.dart';

void main() {
  final planner = RealShellConnectPlanner();

  test('parse injects default routing when command omits routing payload', () {
    final command = ControllerCommand(
      id: 'connect-1',
      kind: ControllerCommandKind.connect,
      issuedAt: DateTime.parse('2026-04-15T00:00:00.000Z'),
      profileId: 'profile-demo',
      arguments: <String, Object?>{
        'profileName': 'demo-profile',
        'serverHost': 'example.com',
        'serverPort': 443,
        'localSocksPort': 1080,
        'sni': 'example.com',
        'verifyTls': true,
        'configPath': '/tmp/runtime-config.json',
      },
      secretArguments: const <String, String>{
        'trojanPassword': 'secret',
      },
    );

    final input = planner.parse(command);
    expect(input, isNotNull);
    expect(input!.profile.routing.mode.name, 'rule');
    expect(input.profile.routing.defaultAction.name, 'proxy');
    expect(input.profile.routing.rules, isEmpty);
  });

  test('parse decodes routing payload from command arguments', () {
    final command = ControllerCommand(
      id: 'connect-2',
      kind: ControllerCommandKind.connect,
      issuedAt: DateTime.parse('2026-04-15T00:00:00.000Z'),
      profileId: 'profile-demo',
      arguments: <String, Object?>{
        'profileName': 'demo-profile',
        'serverHost': 'example.com',
        'serverPort': 443,
        'localSocksPort': 1080,
        'sni': 'example.com',
        'verifyTls': true,
        'configPath': '/tmp/runtime-config.json',
        'routing': <String, Object?>{
          'mode': 'rule',
          'defaultAction': 'proxy',
          'globalAction': 'proxy',
          'policyGroups': <Object?>[
            <String, Object?>{
              'id': 'domestic',
              'name': 'Domestic',
              'action': 'direct',
            }
          ],
          'rules': <Object?>[
            <String, Object?>{
              'id': 'rule-cn',
              'name': 'CN Direct',
              'enabled': true,
              'priority': 10,
              'match': <String, Object?>{
                'domainSuffix': '.cn',
              },
              'action': <String, Object?>{
                'kind': 'policyGroup',
                'policyGroupId': 'domestic',
              },
            }
          ],
        },
      },
      secretArguments: const <String, String>{
        'trojanPassword': 'secret',
      },
    );

    final input = planner.parse(command);
    expect(input, isNotNull);
    expect(input!.profile.routing.policyGroups, hasLength(1));
    expect(input.profile.routing.policyGroups.first.id, 'domestic');
    expect(input.profile.routing.rules, hasLength(1));
    expect(input.profile.routing.rules.first.id, 'rule-cn');
    expect(input.profile.routing.rules.first.action.policyGroupId, 'domestic');
  });
}
