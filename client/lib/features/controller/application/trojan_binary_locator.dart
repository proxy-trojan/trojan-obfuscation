import 'dart:io';

class TrojanBinaryLocator {
  const TrojanBinaryLocator({this.overrideBinaryPath});

  final String? overrideBinaryPath;

  static const List<String> _candidates = <String>[
    '/root/.openclaw/workspace/trojan-obfuscation/build/ci-local/trojan',
    '/root/.openclaw/workspace/trojan-obfuscation/build/ci/trojan',
    '/root/.openclaw/workspace/trojan-obfuscation/build/trojan',
    'trojan',
  ];

  String preferredBinaryPath() => resolveBestEffortBinaryPath();

  String resolveBestEffortBinaryPath() {
    final override = overrideBinaryPath?.trim();
    if (override != null && override.isNotEmpty) {
      return override;
    }

    for (final candidate in _candidates) {
      final looksAbsoluteOrRelativePath = candidate.contains('/') || candidate.contains('\\');
      if (!looksAbsoluteOrRelativePath) {
        continue;
      }
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }
    return _candidates.last;
  }

  List<String> candidates() => List<String>.unmodifiable(_candidates);
}
