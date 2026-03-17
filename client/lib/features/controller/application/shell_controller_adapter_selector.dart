import 'dart:io';

import 'fake_shell_controller_adapter.dart';
import 'real_shell_controller_adapter.dart';
import 'shell_controller_adapter.dart';
import 'trojan_binary_locator.dart';

/// Shell adapter selection result used by bootstrap.
class ShellControllerAdapterSelection {
  const ShellControllerAdapterSelection({
    required this.adapter,
    required this.selectionReason,
    required this.isRealRuntimePath,
  });

  final ShellControllerAdapter adapter;
  final String selectionReason;
  final bool isRealRuntimePath;
}

/// Defines how the app promotes runtime execution from stub to real adapter.
///
/// Promotion rule (Sprint 1 first cut):
/// - supported desktop targets default to `auto`
/// - `auto` prefers real adapter when a launchable trojan binary exists
/// - explicit `real` still falls back to stub with a clear degraded identity
/// - explicit `stub` stays stub
/// - non-desktop targets stay stub
class ShellControllerAdapterSelector {
  ShellControllerAdapterSelector({
    Map<String, String>? environment,
    TrojanBinaryLocator? binaryLocator,
    bool? isSupportedDesktop,
  })  : _environment = environment ?? Platform.environment,
        _binaryLocator = binaryLocator ?? const TrojanBinaryLocator(),
        _isSupportedDesktop =
            isSupportedDesktop ?? _detectSupportedDesktopPlatform();

  final Map<String, String> _environment;
  final TrojanBinaryLocator _binaryLocator;
  final bool _isSupportedDesktop;

  static bool _detectSupportedDesktopPlatform() {
    return Platform.isLinux || Platform.isMacOS || Platform.isWindows;
  }

  ShellControllerAdapterSelection selectForCurrentPlatform() {
    final mode = _backendMode();
    final binaryOverride = _readTrimmed('TROJAN_CLIENT_BINARY');
    final legacyEnableReal = _legacyEnableRealFlag();

    if (!_isSupportedDesktop) {
      return ShellControllerAdapterSelection(
        adapter: FakeShellControllerAdapter(
          backendKind: 'fake-shell-controller-non-desktop',
          runtimeMode: 'stubbed-local-boundary-non-desktop',
          endpointHint: 'in-process://fake-shell-controller/non-desktop',
        ),
        selectionReason:
            'Current platform is not a supported desktop target; keeping stub adapter.',
        isRealRuntimePath: false,
      );
    }

    if (mode == _BackendMode.stub) {
      return ShellControllerAdapterSelection(
        adapter: FakeShellControllerAdapter(
          backendKind: 'fake-shell-controller-explicit',
          runtimeMode: 'stubbed-local-boundary-explicit',
          endpointHint: 'in-process://fake-shell-controller/explicit',
        ),
        selectionReason:
            'TROJAN_CLIENT_BACKEND_MODE=stub; keeping explicit stub adapter.',
        isRealRuntimePath: false,
      );
    }

    final wantsRealAdapter =
        mode == _BackendMode.real || mode == _BackendMode.auto || legacyEnableReal;

    if (wantsRealAdapter) {
      final resolvedBinaryPath = _resolveLaunchableBinaryPath(
        binaryOverride: binaryOverride,
      );
      if (resolvedBinaryPath != null) {
        final reason = mode == _BackendMode.real || legacyEnableReal
            ? 'Real adapter forced and binary resolved.'
            : 'Desktop auto mode resolved trojan binary; promoting real adapter.';
        return ShellControllerAdapterSelection(
          adapter: RealShellControllerAdapter(
            binaryPathHint: resolvedBinaryPath,
            transportEndpointHint: 'process://$resolvedBinaryPath',
            runtimeMode: 'real-runtime-boundary',
            backendKind: 'real-shell-controller',
            backendVersion: 'runtime-path-v1',
          ),
          selectionReason: reason,
          isRealRuntimePath: true,
        );
      }

      return ShellControllerAdapterSelection(
        adapter: FakeShellControllerAdapter(
          backendKind: 'fake-shell-controller-fallback',
          runtimeMode: 'stubbed-local-boundary-fallback',
          endpointHint: 'fallback://real-runtime-unavailable',
        ),
        selectionReason:
            'Real adapter requested/intended but no launchable trojan binary was found; falling back to stub.',
        isRealRuntimePath: false,
      );
    }

    return ShellControllerAdapterSelection(
      adapter: FakeShellControllerAdapter(),
      selectionReason: 'Unknown backend mode; defaulting to stub adapter.',
      isRealRuntimePath: false,
    );
  }

  _BackendMode _backendMode() {
    final raw = _readTrimmed('TROJAN_CLIENT_BACKEND_MODE').toLowerCase();
    return switch (raw) {
      'real' => _BackendMode.real,
      'stub' => _BackendMode.stub,
      _ => _BackendMode.auto,
    };
  }

  bool _legacyEnableRealFlag() {
    final raw = _readTrimmed('TROJAN_CLIENT_ENABLE_REAL_ADAPTER').toLowerCase();
    return raw == '1' || raw == 'true';
  }

  String _readTrimmed(String key) => (_environment[key] ?? '').trim();

  String? _resolveLaunchableBinaryPath({required String binaryOverride}) {
    if (binaryOverride.isNotEmpty) {
      return _resolveCandidate(binaryOverride);
    }

    final preferred = _binaryLocator.preferredBinaryPath();
    return _resolveCandidate(preferred);
  }

  String? _resolveCandidate(String candidate) {
    final trimmed = candidate.trim();
    if (trimmed.isEmpty) return null;

    if (_looksLikePath(trimmed)) {
      return File(trimmed).existsSync() ? trimmed : null;
    }

    return _resolveCommandFromPath(trimmed);
  }

  bool _looksLikePath(String value) {
    return value.contains('/') || value.contains('\\');
  }

  String? _resolveCommandFromPath(String command) {
    final pathValue = _readTrimmed('PATH');
    if (pathValue.isEmpty) return null;

    final separator = Platform.isWindows ? ';' : ':';
    final segments = pathValue.split(separator);

    for (final segment in segments) {
      final dir = segment.trim();
      if (dir.isEmpty) continue;
      final basePath = '$dir${Platform.pathSeparator}$command';
      if (File(basePath).existsSync()) {
        return basePath;
      }
      if (Platform.isWindows) {
        for (final ext in const <String>['.exe', '.bat', '.cmd']) {
          final withExt = '$basePath$ext';
          if (File(withExt).existsSync()) {
            return withExt;
          }
        }
      }
    }
    return null;
  }
}

enum _BackendMode {
  auto,
  real,
  stub,
}
