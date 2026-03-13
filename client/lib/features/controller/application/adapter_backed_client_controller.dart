import 'dart:async';
import 'dart:io';

import '../../profiles/application/profile_secrets_service.dart';
import '../../profiles/domain/client_profile.dart';
import '../../../platform/services/client_filesystem_layout.dart';
import '../domain/client_connection_status.dart';
import '../domain/client_controller_event.dart';
import '../domain/controller_command.dart';
import '../domain/controller_command_result.dart';
import '../domain/controller_runtime_config.dart';
import '../domain/controller_runtime_health.dart';
import '../domain/controller_runtime_session.dart';
import '../domain/controller_telemetry_snapshot.dart';
import 'client_controller_api.dart';
import 'shell_controller_adapter.dart';

class AdapterBackedClientController extends ClientControllerApi {
  AdapterBackedClientController({
    required ShellControllerAdapter adapter,
    required ProfileSecretsService profileSecrets,
    ClientFilesystemLayout? filesystemLayout,
    Duration sessionPollInterval = const Duration(milliseconds: 600),
  })  : _adapter = adapter,
        _profileSecrets = profileSecrets,
        _filesystemLayout = filesystemLayout {
    _lastSessionUpdatedAt = _adapter.session.updatedAt;
    _sessionWatcher = Timer.periodic(sessionPollInterval, (_) {
      final session = _adapter.session;
      final updatedAt = session.updatedAt;
      if (_lastSessionUpdatedAt != updatedAt) {
        _lastSessionUpdatedAt = updatedAt;
        _reconcileStatusWithSession(session);
        notifyListeners();
      }
    });
  }

  static const int _maxEvents = 12;

  final ShellControllerAdapter _adapter;
  final ProfileSecretsService _profileSecrets;
  final ClientFilesystemLayout? _filesystemLayout;
  late final Timer _sessionWatcher;
  DateTime? _lastSessionUpdatedAt;
  int _operationCounter = 0;
  ClientConnectionStatus _status = ClientConnectionStatus.disconnected();
  final List<ClientControllerEvent> _events = <ClientControllerEvent>[
    ClientControllerEvent(
      id: 'boot',
      timestamp: DateTime.now(),
      title: 'Client shell ready',
      message: 'Adapter-backed controller boundary initialized.',
      phase: ClientConnectionPhase.disconnected,
      kind: ClientControllerEventKind.lifecycle,
    ),
  ];

  @override
  ClientConnectionStatus get status => _status;

  @override
  List<ClientControllerEvent> get recentEvents =>
      List<ClientControllerEvent>.unmodifiable(_events);

  @override
  ControllerTelemetrySnapshot get telemetry => _adapter.telemetry;

  @override
  ControllerRuntimeConfig get runtimeConfig => _adapter.runtimeConfig;

  @override
  ControllerRuntimeSession get session => _adapter.session;

  @override
  Future<ControllerRuntimeHealth> checkHealth() => _adapter.checkHealth();

  @override
  Future<ControllerCommandResult> connect(ClientProfile profile) async {
    final operationId = 'connect-${++_operationCounter}';
    final password = await _profileSecrets.readTrojanPassword(profile.id);
    if (password == null || password.trim().isEmpty) {
      final result = ControllerCommandResult(
        commandId: operationId,
        accepted: false,
        completedAt: DateTime.now(),
        summary:
            'Cannot prepare connect plan because no Trojan password is stored for ${profile.name}.',
        error: 'MISSING_TROJAN_PASSWORD',
      );
      _recordEvent(
        title: 'Connect blocked',
        message: result.summary,
        phase: ClientConnectionPhase.error,
        profileId: profile.id,
        kind: ClientControllerEventKind.result,
        operationId: operationId,
        step: 1,
        level: ClientControllerEventLevel.error,
      );
      _status = ClientConnectionStatus(
        phase: ClientConnectionPhase.error,
        message: result.error ?? result.summary,
        updatedAt: DateTime.now(),
        activeProfileId: profile.id,
      );
      notifyListeners();
      return result;
    }

    final commandResult = await _adapter.execute(
      ControllerCommand(
        id: operationId,
        kind: ControllerCommandKind.connect,
        issuedAt: DateTime.now(),
        profileId: profile.id,
        arguments: <String, Object?>{
          'profileName': profile.name,
          'serverHost': profile.serverHost,
          'serverPort': profile.serverPort,
          'localSocksPort': profile.localSocksPort,
          'sni': profile.sni,
          'verifyTls': profile.verifyTls,
          'configPath': _configPathFor(profile.id),
        },
        secretArguments: <String, String>{
          'trojanPassword': password,
        },
      ),
    );

    final runtimeMode = runtimeConfig.mode;
    final acceptedPhase = commandResult.details.containsKey('pid') ||
            runtimeMode == 'stubbed-local-boundary'
        ? ClientConnectionPhase.connected
        : ClientConnectionPhase.connecting;

    _recordEvent(
      title: 'Connect requested',
      message: commandResult.summary,
      phase:
          commandResult.accepted ? acceptedPhase : ClientConnectionPhase.error,
      profileId: profile.id,
      kind: ClientControllerEventKind.action,
      operationId: operationId,
      step: 1,
      level: commandResult.accepted
          ? ClientControllerEventLevel.info
          : ClientControllerEventLevel.error,
    );

    if (!commandResult.accepted) {
      _status = ClientConnectionStatus(
        phase: ClientConnectionPhase.error,
        message: commandResult.error ?? commandResult.summary,
        updatedAt: DateTime.now(),
        activeProfileId: profile.id,
      );
      notifyListeners();
      return commandResult;
    }

    _status = ClientConnectionStatus(
      phase: acceptedPhase,
      message: commandResult.summary,
      updatedAt: DateTime.now(),
      activeProfileId: profile.id,
    );
    notifyListeners();
    return commandResult;
  }

  @override
  Future<ControllerCommandResult> disconnect() async {
    final operationId = 'disconnect-${++_operationCounter}';
    final activeProfileId = _status.activeProfileId;
    final commandResult = await _adapter.execute(
      ControllerCommand(
        id: operationId,
        kind: ControllerCommandKind.disconnect,
        issuedAt: DateTime.now(),
        profileId: activeProfileId,
      ),
    );

    _recordEvent(
      title: 'Disconnect requested',
      message: commandResult.summary,
      phase: commandResult.accepted
          ? ClientConnectionPhase.disconnected
          : ClientConnectionPhase.error,
      profileId: activeProfileId,
      kind: ClientControllerEventKind.result,
      operationId: operationId,
      step: 1,
      level: commandResult.accepted
          ? ClientControllerEventLevel.info
          : ClientControllerEventLevel.error,
    );

    _status = commandResult.accepted
        ? ClientConnectionStatus(
            phase: ClientConnectionPhase.disconnected,
            message: commandResult.summary,
            updatedAt: DateTime.now(),
          )
        : ClientConnectionStatus(
            phase: ClientConnectionPhase.error,
            message: commandResult.error ?? commandResult.summary,
            updatedAt: DateTime.now(),
            activeProfileId: activeProfileId,
          );
    notifyListeners();
    return commandResult;
  }

  String _configPathFor(String profileId) {
    final baseDirectory =
        _filesystemLayout?.stateDirectoryPath ?? Directory.systemTemp.path;
    final safeProfileId = profileId.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return '$baseDirectory${Platform.pathSeparator}runtime${Platform.pathSeparator}runtime-profile-$safeProfileId.json';
  }

  @override
  void dispose() {
    _sessionWatcher.cancel();
    super.dispose();
  }

  void _reconcileStatusWithSession(ControllerRuntimeSession session) {
    if (session.isRunning) {
      if (_status.phase == ClientConnectionPhase.connecting) {
        final summary = session.pid == null
            ? 'Runtime session is active.'
            : 'Runtime session is active. pid=${session.pid}';
        _status = _status.copyWith(
          phase: ClientConnectionPhase.connected,
          message: summary,
          updatedAt: DateTime.now(),
        );
        _recordEvent(
          title: 'Runtime session active',
          message: summary,
          phase: ClientConnectionPhase.connected,
          profileId: _status.activeProfileId,
          kind: ClientControllerEventKind.progress,
          level: ClientControllerEventLevel.info,
        );
      }
      return;
    }

    if (_status.phase != ClientConnectionPhase.connected &&
        _status.phase != ClientConnectionPhase.connecting) {
      return;
    }

    final lastError = session.lastError?.trim();
    final lastExitCode = session.lastExitCode;
    if (lastError != null && lastError.isNotEmpty) {
      final summary = 'Runtime session stopped with error: $lastError';
      _status = _status.copyWith(
        phase: ClientConnectionPhase.error,
        message: summary,
        updatedAt: DateTime.now(),
      );
      _recordEvent(
        title: 'Runtime session ended',
        message: summary,
        phase: ClientConnectionPhase.error,
        profileId: _status.activeProfileId,
        kind: ClientControllerEventKind.result,
        level: ClientControllerEventLevel.error,
      );
      return;
    }

    if (lastExitCode != null && lastExitCode != 0) {
      final summary = 'Runtime session exited with code $lastExitCode.';
      _status = _status.copyWith(
        phase: ClientConnectionPhase.error,
        message: summary,
        updatedAt: DateTime.now(),
      );
      _recordEvent(
        title: 'Runtime session ended',
        message: summary,
        phase: ClientConnectionPhase.error,
        profileId: _status.activeProfileId,
        kind: ClientControllerEventKind.result,
        level: ClientControllerEventLevel.error,
      );
      return;
    }

    final summary = lastExitCode == 0
        ? 'Runtime session ended cleanly.'
        : 'Runtime session is no longer running.';
    _status = ClientConnectionStatus(
      phase: ClientConnectionPhase.disconnected,
      message: summary,
      updatedAt: DateTime.now(),
    );
    _recordEvent(
      title: 'Runtime session ended',
      message: summary,
      phase: ClientConnectionPhase.disconnected,
      profileId: null,
      kind: ClientControllerEventKind.result,
      level: ClientControllerEventLevel.warning,
    );
  }

  void _recordEvent({
    required String title,
    required String message,
    required ClientConnectionPhase phase,
    String? profileId,
    ClientControllerEventLevel level = ClientControllerEventLevel.info,
    ClientControllerEventKind kind = ClientControllerEventKind.lifecycle,
    String? operationId,
    int? step,
  }) {
    final event = ClientControllerEvent(
      id: 'event-${DateTime.now().microsecondsSinceEpoch}',
      timestamp: DateTime.now(),
      title: title,
      message: message,
      phase: phase,
      level: level,
      kind: kind,
      profileId: profileId,
      operationId: operationId,
      step: step,
    );
    _events.insert(0, event);
    if (_events.length > _maxEvents) {
      _events.removeRange(_maxEvents, _events.length);
    }
  }
}
