import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/controller/application/fake_shell_controller_adapter.dart';
import 'package:trojan_pro_client/features/controller/application/real_shell_controller_adapter.dart';
import 'package:trojan_pro_client/features/controller/application/shell_controller_adapter_selector.dart';
import 'package:trojan_pro_client/features/controller/application/trojan_binary_locator.dart';

void main() {
  test('auto mode promotes to real adapter when binary is resolvable', () async {
    final tempDir = await Directory.systemTemp.createTemp('selector-real-test');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final trojanBinary =
        File('${tempDir.path}${Platform.pathSeparator}trojan-real');
    await trojanBinary.writeAsString('#!/bin/sh\nexit 0\n', flush: true);

    final selector = ShellControllerAdapterSelector(
      environment: const <String, String>{},
      binaryLocator: TrojanBinaryLocator(overrideBinaryPath: trojanBinary.path),
      isSupportedDesktop: true,
    );

    final selection = selector.selectForCurrentPlatform();

    expect(selection.isRealRuntimePath, isTrue);
    expect(selection.adapter, isA<RealShellControllerAdapter>());
    expect(selection.adapter.runtimeConfig.mode, 'real-runtime-boundary');
    expect(selection.adapter.telemetry.backendKind, 'real-shell-controller');
  });

  test('auto mode falls back to stub when binary is missing', () {
    final selector = ShellControllerAdapterSelector(
      environment: const <String, String>{},
      binaryLocator:
          const TrojanBinaryLocator(overrideBinaryPath: '/nonexistent/trojan'),
      isSupportedDesktop: true,
    );

    final selection = selector.selectForCurrentPlatform();

    expect(selection.isRealRuntimePath, isFalse);
    expect(selection.adapter, isA<FakeShellControllerAdapter>());
    expect(
      selection.adapter.runtimeConfig.mode,
      'stubbed-local-boundary-fallback',
    );
    expect(
      selection.selectionReason,
      contains('no launchable trojan binary was found'),
    );
  });

  test('explicit stub mode keeps stub even when binary exists', () async {
    final tempDir = await Directory.systemTemp.createTemp('selector-stub-test');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final trojanBinary =
        File('${tempDir.path}${Platform.pathSeparator}trojan-stub');
    await trojanBinary.writeAsString('#!/bin/sh\nexit 0\n', flush: true);

    final selector = ShellControllerAdapterSelector(
      environment: <String, String>{
        'TROJAN_CLIENT_BACKEND_MODE': 'stub',
      },
      binaryLocator: TrojanBinaryLocator(overrideBinaryPath: trojanBinary.path),
      isSupportedDesktop: true,
    );

    final selection = selector.selectForCurrentPlatform();

    expect(selection.isRealRuntimePath, isFalse);
    expect(selection.adapter, isA<FakeShellControllerAdapter>());
    expect(
      selection.adapter.runtimeConfig.mode,
      'stubbed-local-boundary-explicit',
    );
  });

  test('explicit real mode degrades to fallback stub when binary is missing', () {
    final selector = ShellControllerAdapterSelector(
      environment: <String, String>{
        'TROJAN_CLIENT_BACKEND_MODE': 'real',
      },
      binaryLocator:
          const TrojanBinaryLocator(overrideBinaryPath: '/nonexistent/trojan'),
      isSupportedDesktop: true,
    );

    final selection = selector.selectForCurrentPlatform();

    expect(selection.isRealRuntimePath, isFalse);
    expect(selection.adapter, isA<FakeShellControllerAdapter>());
    expect(
      selection.adapter.runtimeConfig.mode,
      'stubbed-local-boundary-fallback',
    );
  });

  test('non-desktop target keeps non-desktop stub mode', () {
    final selector = ShellControllerAdapterSelector(
      environment: const <String, String>{},
      binaryLocator:
          const TrojanBinaryLocator(overrideBinaryPath: '/any/path/trojan'),
      isSupportedDesktop: false,
    );

    final selection = selector.selectForCurrentPlatform();

    expect(selection.isRealRuntimePath, isFalse);
    expect(selection.adapter, isA<FakeShellControllerAdapter>());
    expect(
      selection.adapter.runtimeConfig.mode,
      'stubbed-local-boundary-non-desktop',
    );
  });

  test('legacy real-adapter flag still promotes when binary is available',
      () async {
    final tempDir =
        await Directory.systemTemp.createTemp('selector-legacy-real-test');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final trojanBinary =
        File('${tempDir.path}${Platform.pathSeparator}trojan-legacy');
    await trojanBinary.writeAsString('#!/bin/sh\nexit 0\n', flush: true);

    final selector = ShellControllerAdapterSelector(
      environment: <String, String>{
        'TROJAN_CLIENT_ENABLE_REAL_ADAPTER': '1',
      },
      binaryLocator: TrojanBinaryLocator(overrideBinaryPath: trojanBinary.path),
      isSupportedDesktop: true,
    );

    final selection = selector.selectForCurrentPlatform();

    expect(selection.isRealRuntimePath, isTrue);
    expect(selection.adapter, isA<RealShellControllerAdapter>());
  });
}
