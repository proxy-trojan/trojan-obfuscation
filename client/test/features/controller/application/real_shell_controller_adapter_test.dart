import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/controller/application/real_shell_controller_adapter.dart';
import 'package:trojan_pro_client/features/controller/domain/controller_command.dart';
import 'package:trojan_pro_client/features/controller/domain/controller_runtime_session.dart';

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

ControllerCommand _disconnectCommand() {
  return ControllerCommand(
    id: 'disconnect-1',
    kind: ControllerCommandKind.disconnect,
    issuedAt: DateTime.now(),
    profileId: 'profile-demo',
  );
}

Future<File> _writeFakeTrojanScript(Directory tempDir) async {
  final script = File(
    '${tempDir.path}${Platform.pathSeparator}fake-trojan.py',
  );
  await script.writeAsString('''#!/usr/bin/env python3
import signal
import sys
import time

config_path = None
args = sys.argv[1:]
for index, value in enumerate(args):
    if value == '-c' and index + 1 < len(args):
        config_path = args[index + 1]

print(f"fake trojan boot {config_path}", flush=True)
print("fake trojan stderr", file=sys.stderr, flush=True)

def stop(signum, frame):
    print("fake trojan shutdown", flush=True)
    sys.exit(0)

signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGINT, stop)

while True:
    time.sleep(1)
''', flush: true);
  await Process.run('chmod', <String>['+x', script.path]);
  return script;
}

Future<File> _writeModeAwareFakeTrojanScript(
  Directory tempDir,
  String modeFilePath,
) async {
  final script = File(
    '${tempDir.path}${Platform.pathSeparator}fake-trojan-mode-aware.py',
  );
  await script.writeAsString('''#!/usr/bin/env python3
import pathlib
import signal
import sys
import time

mode_path = pathlib.Path(r"$modeFilePath")
mode = mode_path.read_text().strip() if mode_path.exists() else "run"

config_path = None
args = sys.argv[1:]
for index, value in enumerate(args):
    if value == '-c' and index + 1 < len(args):
        config_path = args[index + 1]

print(f"fake trojan mode={mode} config={config_path}", flush=True)
print("fake trojan mode-aware stderr", file=sys.stderr, flush=True)

if mode == "fail":
    time.sleep(0.3)
    sys.exit(17)

def stop(signum, frame):
    print("fake trojan mode-aware shutdown", flush=True)
    sys.exit(0)

signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGINT, stop)

while True:
    time.sleep(1)
''', flush: true);
  await Process.run('chmod', <String>['+x', script.path]);
  return script;
}

Future<void> _waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 3),
  Duration step = const Duration(milliseconds: 25),
  required String description,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (condition()) {
      return;
    }
    await Future<void>.delayed(step);
  }
  fail('Timed out waiting for: $description');
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
    expect(
      result.summary,
      contains('Failed to execute trojan client launch plan'),
    );
    expect(
      result.details['configPreview'],
      isNot(contains('super-secret-password')),
    );
    expect(await File(configPath).exists(), isFalse);
    expect(adapter.session.lastError, isNotNull);
    expect(adapter.session.phase, ControllerRuntimePhase.failed);
  });

  test('launches fake runtime, captures logs, and cleans config on disconnect',
      () async {
    final tempDir = await Directory.systemTemp
        .createTemp('real-shell-adapter-success-test');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final fakeTrojan = await _writeFakeTrojanScript(tempDir);
    final configPath =
        '${tempDir.path}${Platform.pathSeparator}runtime-config.json';
    final adapter = RealShellControllerAdapter(
      binaryPathHint: fakeTrojan.path,
      transportEndpointHint: 'local-controller://test',
    );

    final connectResult =
        await adapter.execute(_connectCommand(configPath: configPath));

    expect(connectResult.accepted, isTrue);
    expect(connectResult.details['pid'], isNotNull);
    expect(await File(configPath).exists(), isTrue);
    expect(adapter.session.isRunning, isTrue);
    expect(
      adapter.session.phase,
      anyOf(
        ControllerRuntimePhase.alive,
        ControllerRuntimePhase.sessionReady,
      ),
    );

    await _waitFor(
      () => adapter.session.stdoutTail
          .any((line) => line.contains('fake trojan boot')),
      description: 'stdout boot log',
    );
    await _waitFor(
      () => adapter.session.stderrTail
          .any((line) => line.contains('fake trojan stderr')),
      description: 'stderr boot log',
    );

    final disconnectResult = await adapter.execute(_disconnectCommand());
    expect(disconnectResult.accepted, isTrue);
    expect(adapter.session.stopRequested, isTrue);
    expect(adapter.session.stopRequestedAt, isNotNull);

    await _waitFor(
      () => !adapter.session.isRunning,
      description: 'runtime shutdown',
    );
    await _waitFor(
      () => !File(configPath).existsSync(),
      description: 'runtime config cleanup',
    );

    expect(adapter.session.activeConfigPath, isNull);
    expect(adapter.session.phase, ControllerRuntimePhase.stopped);
  });

  test('abnormal exit cleanup keeps adapter retry-safe for next launch',
      () async {
    final tempDir =
        await Directory.systemTemp.createTemp('real-shell-adapter-retry-test');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final modeFile =
        File('${tempDir.path}${Platform.pathSeparator}fake-trojan.mode');
    await modeFile.writeAsString('fail', flush: true);

    final fakeTrojan = await _writeModeAwareFakeTrojanScript(
      tempDir,
      modeFile.path,
    );
    final configPath =
        '${tempDir.path}${Platform.pathSeparator}runtime-retry-config.json';

    final adapter = RealShellControllerAdapter(
      binaryPathHint: fakeTrojan.path,
      transportEndpointHint: 'local-controller://test',
    );

    final firstConnect =
        await adapter.execute(_connectCommand(configPath: configPath));
    expect(firstConnect.accepted, isTrue);

    await _waitFor(
      () => !adapter.session.isRunning,
      description: 'runtime exits after forced failure mode',
    );
    await _waitFor(
      () => !File(configPath).existsSync(),
      description: 'failed runtime launch config cleanup',
    );

    expect(adapter.session.phase, ControllerRuntimePhase.failed);
    expect(adapter.session.lastExitCode, 17);
    expect(adapter.session.activeConfigPath, isNull);

    await modeFile.writeAsString('run', flush: true);

    final secondConnect =
        await adapter.execute(_connectCommand(configPath: configPath));
    expect(secondConnect.accepted, isTrue);
    expect(adapter.session.isRunning, isTrue);

    final disconnectResult = await adapter.execute(_disconnectCommand());
    expect(disconnectResult.accepted, isTrue);

    await _waitFor(
      () => !adapter.session.isRunning,
      description: 'runtime exits after retry disconnect',
    );
    await _waitFor(
      () => !File(configPath).existsSync(),
      description: 'retry runtime config cleanup',
    );

    expect(adapter.session.phase, ControllerRuntimePhase.stopped);
    expect(adapter.session.activeConfigPath, isNull);
  });
}
