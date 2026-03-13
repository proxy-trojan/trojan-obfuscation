import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/controller/application/real_shell_controller_adapter.dart';
import 'package:trojan_pro_client/features/controller/domain/controller_command.dart';

ControllerCommand _connectCommand({required String configPath}) {
  return ControllerCommand(
    id: 'connect-1',
    kind: ControllerCommandKind.connect,
    issuedAt: DateTime.now(),
    profileId: 'profile-demo',
    arguments: <String, Object?>{
      'profileName': 'demo-profile',
      'serverHost': 'example.com',
      'serverPort': 443,
      'localSocksPort': 1080,
      'sni': 'example.com',
      'verifyTls': true,
      'configPath': configPath,
    },
    secretArguments: const <String, String>{
      'trojanPassword': 'super-secret-password',
    },
  );
}

void main() {
  test('cleans up rendered config file when process start fails', () async {
    final tempDir =
        await Directory.systemTemp.createTemp('real-shell-adapter-test');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final configPath =
        '${tempDir.path}${Platform.pathSeparator}runtime-config.json';
    final missingBinaryPath =
        '${tempDir.path}${Platform.pathSeparator}missing-binary${Platform.pathSeparator}trojan';

    final adapter = RealShellControllerAdapter(
      binaryPathHint: missingBinaryPath,
      transportEndpointHint: 'local-controller://test',
    );

    final result =
        await adapter.execute(_connectCommand(configPath: configPath));

    expect(result.accepted, isFalse);
    expect(result.summary,
        contains('Failed to execute trojan client launch plan'));
    expect(result.details['configPreview'],
        isNot(contains('super-secret-password')));
    expect(await File(configPath).exists(), isFalse);
    expect(adapter.session.lastError, isNotNull);
  });
}
