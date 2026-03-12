import 'dart:io';

class ClientFilesystemLayout {
  const ClientFilesystemLayout({
    required this.stateDirectoryPath,
    required this.diagnosticsDirectoryPath,
  });

  final String stateDirectoryPath;
  final String diagnosticsDirectoryPath;

  static ClientFilesystemLayout? maybeForCurrentPlatform() {
    if (Platform.isLinux) {
      final stateRoot = _env('XDG_STATE_HOME') ?? _homeJoin('.local', 'state');
      if (stateRoot == null) return null;
      final appRoot = _join(stateRoot, 'trojan-pro-client');
      return ClientFilesystemLayout(
        stateDirectoryPath: _join(appRoot, 'state'),
        diagnosticsDirectoryPath: _join(appRoot, 'diagnostics'),
      );
    }

    if (Platform.isMacOS) {
      final appRoot = _homeJoin('Library', 'Application Support', 'TrojanProClient');
      if (appRoot == null) return null;
      return ClientFilesystemLayout(
        stateDirectoryPath: _join(appRoot, 'state'),
        diagnosticsDirectoryPath: _join(appRoot, 'diagnostics'),
      );
    }

    if (Platform.isWindows) {
      final appData = _env('APPDATA') ?? _homeJoin('AppData', 'Roaming');
      if (appData == null) return null;
      final appRoot = _join(appData, 'TrojanProClient');
      return ClientFilesystemLayout(
        stateDirectoryPath: _join(appRoot, 'state'),
        diagnosticsDirectoryPath: _join(appRoot, 'diagnostics'),
      );
    }

    return null;
  }

  static String? _homeJoin(String first, [String? second, String? third]) {
    final home = _env('HOME') ?? _env('USERPROFILE');
    if (home == null) return null;
    return _join(home, first, second, third);
  }

  static String? _env(String key) {
    final value = Platform.environment[key];
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String _join(String first, [String? second, String? third, String? fourth]) {
    final segments = <String>[
      first,
      if (second != null) second,
      if (third != null) third,
      if (fourth != null) fourth,
    ];

    var result = segments.first;
    for (final rawSegment in segments.skip(1)) {
      final segment = _trimSeparators(rawSegment);
      if (segment.isEmpty) continue;
      final separator = Platform.pathSeparator;
      if (result.endsWith('/') || result.endsWith('\\')) {
        result = '$result$segment';
      } else {
        result = '$result$separator$segment';
      }
    }
    return result;
  }

  static String _trimSeparators(String value) {
    var start = 0;
    var end = value.length;

    while (start < end && _isSeparator(value.codeUnitAt(start))) {
      start += 1;
    }
    while (end > start && _isSeparator(value.codeUnitAt(end - 1))) {
      end -= 1;
    }

    return value.substring(start, end);
  }

  static bool _isSeparator(int codeUnit) {
    return codeUnit == 47 || codeUnit == 92;
  }
}
