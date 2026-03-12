class ControllerRuntimeSession {
  const ControllerRuntimeSession({
    required this.isRunning,
    required this.updatedAt,
    this.pid,
    this.activeConfigPath,
    this.lastExitCode,
    this.lastError,
    this.stdoutTail = const <String>[],
    this.stderrTail = const <String>[],
  });

  final bool isRunning;
  final DateTime updatedAt;
  final int? pid;
  final String? activeConfigPath;
  final int? lastExitCode;
  final String? lastError;
  final List<String> stdoutTail;
  final List<String> stderrTail;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'isRunning': isRunning,
      'updatedAt': updatedAt.toIso8601String(),
      'pid': pid,
      'activeConfigPath': activeConfigPath,
      'lastExitCode': lastExitCode,
      'lastError': lastError,
      'stdoutTail': stdoutTail,
      'stderrTail': stderrTail,
    };
  }
}
