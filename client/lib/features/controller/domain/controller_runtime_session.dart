import 'controller_launch_plan.dart';

enum ControllerRuntimePhase {
  stopped,
  planned,
  launching,
  alive,
  sessionReady,
  failed,
}

enum ControllerRuntimeSessionTruth {
  stopped,
  stopping,
  live,
  aging,
  stale,
  residual,
}

extension ControllerRuntimeSessionTruthLabel on ControllerRuntimeSessionTruth {
  String get label => switch (this) {
        ControllerRuntimeSessionTruth.stopped => 'Stopped',
        ControllerRuntimeSessionTruth.stopping => 'Stopping',
        ControllerRuntimeSessionTruth.live => 'Live',
        ControllerRuntimeSessionTruth.aging => 'Aging',
        ControllerRuntimeSessionTruth.stale => 'Stale',
        ControllerRuntimeSessionTruth.residual => 'Residual snapshot',
      };
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

extension ControllerRuntimeSessionStateX on ControllerRuntimeSession {
  Duration get age {
    final now = DateTime.now();
    return now.isAfter(updatedAt) ? now.difference(updatedAt) : Duration.zero;
  }

  String get ageLabel {
    final sessionAge = age;
    if (sessionAge.inSeconds < 5) {
      return 'just now';
    }
    if (sessionAge.inMinutes < 1) {
      return '${sessionAge.inSeconds}s ago';
    }
    if (sessionAge.inHours < 1) {
      return '${sessionAge.inMinutes}m ago';
    }
    return '${sessionAge.inHours}h ago';
  }

  ControllerRuntimeSessionTruth get truth {
    if (stopRequested) {
      return ControllerRuntimeSessionTruth.stopping;
    }
    if (!isRunning && phase == ControllerRuntimePhase.stopped) {
      return ControllerRuntimeSessionTruth.stopped;
    }
    if (!isRunning) {
      return ControllerRuntimeSessionTruth.residual;
    }
    if (age >= const Duration(minutes: 2)) {
      return ControllerRuntimeSessionTruth.stale;
    }
    if (age >= const Duration(seconds: 30)) {
      return ControllerRuntimeSessionTruth.aging;
    }
    return ControllerRuntimeSessionTruth.live;
  }

  String get truthNote => switch (truth) {
        ControllerRuntimeSessionTruth.stopped =>
          'No managed runtime session is active right now.',
        ControllerRuntimeSessionTruth.stopping =>
          'A stop request is in flight; wait for exit confirmation before trusting the session as closed.',
        ControllerRuntimeSessionTruth.live =>
          'The managed runtime session looks current and recently refreshed.',
        ControllerRuntimeSessionTruth.aging =>
          'The managed runtime session still looks alive, but its snapshot is getting older.',
        ControllerRuntimeSessionTruth.stale =>
          'The managed runtime session snapshot looks stale and should be revalidated before trusting it.',
        ControllerRuntimeSessionTruth.residual =>
          'The shell still has a non-stopped session record even though no runtime is marked as running. Treat this as residual state until recovery clears it.',
      };
}
