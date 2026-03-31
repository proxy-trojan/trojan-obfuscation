import 'dart:convert';
import 'dart:io';

import '../../controller/application/client_controller_api.dart';
import '../../controller/domain/controller_runtime_health.dart';
import '../../profiles/application/profile_secrets_service.dart';
import '../../profiles/application/profile_store.dart';
import '../../profiles/domain/client_profile.dart';
import '../../../platform/secure_storage/secure_storage.dart';
import '../../../platform/services/client_filesystem_layout.dart';
import '../../../platform/services/local_state_store.dart';
import '../../controller/domain/runtime_posture.dart';
import '../domain/readiness_report.dart';

class ReadinessService {
  ReadinessService({
    required ProfileStore profileStore,
    required ProfileSecretsService profileSecrets,
    required SecureStorage secureStorage,
    required ClientControllerApi controller,
    ClientFilesystemLayout? filesystemLayout,
    LocalStateStore? localStateStore,
  })  : _profileStore = profileStore,
        _profileSecrets = profileSecrets,
        _secureStorage = secureStorage,
        _controller = controller,
        _filesystemLayout = filesystemLayout,
        _localStateStore = localStateStore;

  final ProfileStore _profileStore;
  final ProfileSecretsService _profileSecrets;
  final SecureStorage _secureStorage;
  final ClientControllerApi _controller;
  final ClientFilesystemLayout? _filesystemLayout;
  final LocalStateStore? _localStateStore;

  Future<ReadinessReport> buildReport({ClientProfile? profileOverride}) async {
    final checks = <ReadinessCheck>[];
    final selectedProfile = profileOverride ?? _profileStore.selectedProfile;

    checks.add(_checkProfile(selectedProfile));
    checks.add(await _checkPassword(selectedProfile));
    checks.add(_checkSecureStorage());
    checks.add(_checkEnvironment());
    checks.add(_checkConfig(selectedProfile));
    checks.add(_checkRuntimePath());
    checks.add(await _checkRuntimeBinary());
    checks.add(await _checkFilesystem());

    final report = ReadinessReport.fromChecks(checks);
    await _persistLastKnownReport(report, profile: selectedProfile);
    return report;
  }

  Future<ReadinessReport?> readLastKnownReport({
    ClientProfile? profileOverride,
  }) async {
    final localStateStore = _localStateStore;
    if (localStateStore == null) return null;
    final selectedProfile = profileOverride ?? _profileStore.selectedProfile;
    final raw = await localStateStore.read(_storageKeyFor(selectedProfile));
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final report = ReadinessReport.fromJson(jsonDecode(raw));
      return report?.copyWith(isCachedSnapshot: true);
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistLastKnownReport(
    ReadinessReport report, {
    required ClientProfile? profile,
  }) async {
    final localStateStore = _localStateStore;
    if (localStateStore == null) return;
    await localStateStore.write(
      _storageKeyFor(profile),
      jsonEncode(report.toJson()),
    );
  }

  String _storageKeyFor(ClientProfile? profile) {
    return profile == null
        ? 'client.readiness.last-known.none'
        : 'client.readiness.last-known.${profile.id}';
  }

  ReadinessCheck _checkProfile(ClientProfile? profile) {
    if (profile == null) {
      return const ReadinessCheck(
        domain: ReadinessDomain.profile,
        level: ReadinessLevel.blocked,
        summary: 'No profile is selected yet.',
        detail: 'Pick or import one profile before running a connection test.',
        action: ReadinessAction.openProfiles,
        actionLabel: 'Open Profiles',
      );
    }
    return ReadinessCheck(
      domain: ReadinessDomain.profile,
      level: ReadinessLevel.ready,
      summary: 'Selected profile: ${profile.name}.',
    );
  }

  Future<ReadinessCheck> _checkPassword(ClientProfile? profile) async {
    if (profile == null) {
      return const ReadinessCheck(
        domain: ReadinessDomain.password,
        level: ReadinessLevel.ready,
        summary: 'Password check awaits profile selection.',
      );
    }

    final hasPassword = await _profileSecrets.hasTrojanPassword(profile.id);
    if (!hasPassword) {
      return ReadinessCheck(
        domain: ReadinessDomain.password,
        level: ReadinessLevel.blocked,
        summary: 'Trojan password has not been saved for ${profile.name}.',
        detail: 'Save the password first so the connect plan can be built.',
        action: ReadinessAction.openProfiles,
        actionLabel: 'Open Profiles',
      );
    }

    return ReadinessCheck(
      domain: ReadinessDomain.password,
      level: ReadinessLevel.ready,
      summary: 'Password is stored for ${profile.name}.',
    );
  }

  ReadinessCheck _checkSecureStorage() {
    final status = _secureStorage.status;
    if (!status.isPersistent) {
      return ReadinessCheck(
        domain: ReadinessDomain.secureStorage,
        level: ReadinessLevel.degraded,
        summary: status.userFacingSummary,
        detail:
            'Storage is session-only. Restarting the app may require re-entering passwords.',
        action: ReadinessAction.openTroubleshooting,
        actionLabel: 'Open Troubleshooting',
      );
    }

    if (status.fallbackActive) {
      return ReadinessCheck(
        domain: ReadinessDomain.secureStorage,
        level: ReadinessLevel.degraded,
        summary: status.userFacingSummary,
        detail: status.lastPrimaryError,
        action: ReadinessAction.openTroubleshooting,
        actionLabel: 'Open Troubleshooting',
      );
    }

    return ReadinessCheck(
      domain: ReadinessDomain.secureStorage,
      level: ReadinessLevel.ready,
      summary: status.userFacingSummary,
    );
  }

  ReadinessCheck _checkEnvironment() {
    if (_filesystemLayout == null) {
      return const ReadinessCheck(
        domain: ReadinessDomain.environment,
        level: ReadinessLevel.degraded,
        summary: 'Desktop environment capabilities are partial.',
        detail:
            'Platform-specific filesystem layout is unavailable; runtime artifacts may rely on temp paths.',
        action: ReadinessAction.openTroubleshooting,
        actionLabel: 'Open Troubleshooting',
      );
    }
    return const ReadinessCheck(
      domain: ReadinessDomain.environment,
      level: ReadinessLevel.ready,
      summary: 'Desktop environment capabilities look available.',
    );
  }

  ReadinessCheck _checkConfig(ClientProfile? profile) {
    if (profile == null) {
      return const ReadinessCheck(
        domain: ReadinessDomain.config,
        level: ReadinessLevel.ready,
        summary: 'Config check awaits profile selection.',
      );
    }

    final invalidHost = profile.serverHost.trim().isEmpty;
    final invalidServerPort =
        profile.serverPort <= 0 || profile.serverPort > 65535;
    final invalidLocalPort =
        profile.localSocksPort <= 0 || profile.localSocksPort > 65535;

    if (invalidHost || invalidServerPort || invalidLocalPort) {
      return ReadinessCheck(
        domain: ReadinessDomain.config,
        level: ReadinessLevel.blocked,
        summary: 'Profile config for ${profile.name} is invalid.',
        detail:
            'Check server host / server port / local SOCKS port before connecting.',
        action: ReadinessAction.openProfiles,
        actionLabel: 'Open Profiles',
      );
    }

    return ReadinessCheck(
      domain: ReadinessDomain.config,
      level: ReadinessLevel.ready,
      summary: 'Profile config for ${profile.name} looks valid.',
    );
  }

  ReadinessCheck _checkRuntimePath() {
    final posture = describeRuntimePosture(
      runtimeMode: _controller.runtimeConfig.mode,
      backendKind: _controller.telemetry.backendKind,
    );
    if (posture.isStubOnly) {
      return ReadinessCheck(
        domain: ReadinessDomain.runtimePath,
        level: ReadinessLevel.degraded,
        summary:
            'Runtime posture is ${posture.postureLabel.toLowerCase()} (${posture.runtimeMode.replaceAll('-', ' ')}).',
        detail: posture.truthNote,
        action: ReadinessAction.openTroubleshooting,
        actionLabel: 'Open Troubleshooting',
      );
    }

    return const ReadinessCheck(
      domain: ReadinessDomain.runtimePath,
      level: ReadinessLevel.ready,
      summary: 'Runtime path is real.',
    );
  }

  Future<ReadinessCheck> _checkRuntimeBinary() async {
    final health = await _controller.checkHealth();
    switch (health.level) {
      case ControllerRuntimeHealthLevel.healthy:
        return ReadinessCheck(
          domain: ReadinessDomain.runtimeBinary,
          level: ReadinessLevel.ready,
          summary: health.summary,
        );
      case ControllerRuntimeHealthLevel.degraded:
        return ReadinessCheck(
          domain: ReadinessDomain.runtimeBinary,
          level: ReadinessLevel.degraded,
          summary: health.summary,
          action: ReadinessAction.openTroubleshooting,
          actionLabel: 'Open Troubleshooting',
        );
      case ControllerRuntimeHealthLevel.unavailable:
        return ReadinessCheck(
          domain: ReadinessDomain.runtimeBinary,
          level: ReadinessLevel.blocked,
          summary: health.summary,
          detail: 'Fix the runtime binary before attempting a connection.',
          action: ReadinessAction.openTroubleshooting,
          actionLabel: 'Open Troubleshooting',
        );
    }
  }

  Future<ReadinessCheck> _checkFilesystem() async {
    final layout = _filesystemLayout;
    if (layout == null) {
      return const ReadinessCheck(
        domain: ReadinessDomain.filesystem,
        level: ReadinessLevel.degraded,
        summary:
            'Filesystem layout is unavailable; runtime artifacts will use temp paths.',
        detail:
            'This can happen on unsupported platforms. It is OK for testing but not for persistent runtime use.',
      );
    }

    final stateDirectory = Directory(layout.stateDirectoryPath);
    try {
      await stateDirectory.create(recursive: true);
      final probeFile = File(
        '${stateDirectory.path}${Platform.pathSeparator}readiness_probe.txt',
      );
      await probeFile.writeAsString('ok', flush: true);
      await probeFile.delete();
      return const ReadinessCheck(
        domain: ReadinessDomain.filesystem,
        level: ReadinessLevel.ready,
        summary: 'Managed runtime path is writable.',
      );
    } catch (error) {
      return ReadinessCheck(
        domain: ReadinessDomain.filesystem,
        level: ReadinessLevel.blocked,
        summary: 'Managed runtime path is not writable.',
        detail: error.toString(),
        action: ReadinessAction.openTroubleshooting,
        actionLabel: 'Open Troubleshooting',
      );
    }
  }
}
