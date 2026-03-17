import 'controller_launch_plan.dart';

enum ControllerRuntimePhase {
  stopped,
  planned,
  launching,
  alive,
  sessionReady,
  failed,
}

class ControllerRuntimeSession {
  const ControllerRuntimeSession({
    required this.isRunning,
    required this.updatedAt,
    this.phase = ControllerRuntimePhase.stopped,
    this.stopRequested = false,
    this.stopRequestedAt,
    this.pid,
    this.activeConfigPath,
    this.configProvenance,
    this.expectedLocalSocksPort,
    this.launchPlan,
    this.lastExitCode,
    this.lastError,
    this.stdoutTail = const <String>[],
    this.stderrTail = const <String>[],
  });

  final bool isRunning;
  final DateTime updatedAt;
  final ControllerRuntimePhase phase;
  final bool stopRequested;
  final DateTime? stopRequestedAt;
  final int? pid;
  final String? activeConfigPath;
  final String? configProvenance;
  final int? expectedLocalSocksPort;
  final ControllerLaunchPlan? launchPlan;
  final int? lastExitCode;
  final String? lastError;
  final List<String> stdoutTail;
  final List<String> stderrTail;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'isRunning': isRunning,
      'updatedAt': updatedAt.toIso8601String(),
      'phase': phase.name,
      'stopRequested': stopRequested,
      'stopRequestedAt': stopRequestedAt?.toIso8601String(),
      'pid': pid,
      'activeConfigPath': activeConfigPath,
      'configProvenance': configProvenance,
      'expectedLocalSocksPort': expectedLocalSocksPort,
      'launchPlan': launchPlan?.toJson(),
      'lastExitCode': lastExitCode,
      'lastError': lastError,
      'stdoutTail': stdoutTail,
      'stderrTail': stderrTail,
    };
  }
}
