import '../../profiles/domain/client_profile.dart';
import '../domain/client_connection_status.dart';
import '../domain/client_controller_event.dart';
import '../domain/controller_command.dart';
import '../domain/controller_command_result.dart';
import '../domain/controller_runtime_config.dart';
import '../domain/controller_runtime_health.dart';
import '../domain/controller_runtime_session.dart';
import '../domain/controller_telemetry_snapshot.dart';
import '../domain/last_runtime_failure_summary.dart';
import 'client_controller_api.dart';
import 'fake_shell_controller_adapter.dart';

class FakeClientController extends ClientControllerApi {
  static const int _maxEvents = 12;
  int _operationCounter = 0;

  final FakeShellControllerAdapter _adapter = FakeShellControllerAdapter();
  ClientConnectionStatus _status = ClientConnectionStatus.disconnected();
  final List<ClientControllerEvent> _events = <ClientControllerEvent>[
    ClientControllerEvent(
      id: 'boot',
      timestamp: DateTime.now(),
      title: 'Client shell ready',
      message:
          'Fake controller boundary initialized for product-layer validation.',
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
  LastRuntimeFailureSummary? get lastRuntimeFailure => null;

  @override
  Future<ControllerRuntimeHealth> checkHealth() => _adapter.checkHealth();

  @override
  Future<ControllerCommandResult> connect(ClientProfile profile) async {
    final operationId = 'connect-${++_operationCounter}';
    final commandResult = await _adapter.execute(
      ControllerCommand(
        id: operationId,
        kind: ControllerCommandKind.connect,
        issuedAt: DateTime.now(),
        profileId: profile.id,
        arguments: <String, Object?>{
          'profileName': profile.name,
          'serverHost': profile.serverHost,
        },
      ),
    );
    _recordEvent(
      title: 'Connect requested',
      message:
          'User requested a connection using ${profile.name}. ${commandResult.summary}',
      phase: ClientConnectionPhase.connecting,
      profileId: profile.id,
      kind: ClientControllerEventKind.action,
      operationId: operationId,
      step: 1,
    );
    _status = ClientConnectionStatus(
      phase: ClientConnectionPhase.connecting,
      message: 'Resolving ${profile.serverHost}...',
      updatedAt: DateTime.now(),
      activeProfileId: profile.id,
    );
    notifyListeners();

    await Future<void>.delayed(const Duration(milliseconds: 350));

    _recordEvent(
      title: 'DNS resolution completed',
      message:
          'Resolved ${profile.serverHost}; preparing secure session bootstrap.',
      phase: ClientConnectionPhase.connecting,
      profileId: profile.id,
      kind: ClientControllerEventKind.progress,
      operationId: operationId,
      step: 2,
    );
    _status = _status.copyWith(
      phase: ClientConnectionPhase.connecting,
      message: 'Establishing secure session for ${profile.name}...',
      updatedAt: DateTime.now(),
    );
    notifyListeners();

    await Future<void>.delayed(const Duration(milliseconds: 450));

    _recordEvent(
      title: 'Connection established',
      message: 'Fake controller reported a successful connected state.',
      phase: ClientConnectionPhase.connected,
      profileId: profile.id,
      kind: ClientControllerEventKind.result,
      operationId: operationId,
      step: 3,
    );
    _status = ClientConnectionStatus(
      phase: ClientConnectionPhase.connected,
      message: 'Connected via fake controller boundary',
      updatedAt: DateTime.now(),
      activeProfileId: profile.id,
    );
    notifyListeners();

    return ControllerCommandResult(
      commandId: operationId,
      accepted: true,
      completedAt: DateTime.now(),
      summary: 'Connection flow completed in fake controller boundary.',
    );
  }

  @override
  Future<ControllerCommandResult> disconnect() async {
    final activeProfileId = _status.activeProfileId;
    final operationId = 'disconnect-${++_operationCounter}';
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
      message:
          'Connection torn down from the shell action. ${commandResult.summary}',
      phase: ClientConnectionPhase.disconnecting,
      profileId: activeProfileId,
      kind: ClientControllerEventKind.result,
      operationId: operationId,
      step: 1,
    );
    _status = ClientConnectionStatus(
      phase: ClientConnectionPhase.disconnecting,
      message: 'Disconnecting current session...',
      updatedAt: DateTime.now(),
      activeProfileId: activeProfileId,
    );
    notifyListeners();

    await Future<void>.delayed(const Duration(milliseconds: 180));

    _recordEvent(
      title: 'Connection closed',
      message: 'Fake controller reported a clean disconnect.',
      phase: ClientConnectionPhase.disconnected,
      profileId: activeProfileId,
      kind: ClientControllerEventKind.result,
      operationId: operationId,
      step: 2,
    );
    _status = ClientConnectionStatus.disconnected();
    notifyListeners();
    return commandResult;
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
