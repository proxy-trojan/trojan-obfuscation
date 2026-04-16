import 'client_connection_status.dart';

enum ClientControllerEventLevel {
  info,
  warning,
  error,
}

enum ClientControllerEventKind {
  lifecycle,
  action,
  progress,
  result,
}

class ClientControllerEvent {
  const ClientControllerEvent({
    required this.id,
    required this.timestamp,
    required this.title,
    required this.message,
    required this.phase,
    this.level = ClientControllerEventLevel.info,
    this.kind = ClientControllerEventKind.lifecycle,
    this.profileId,
    this.operationId,
    this.step,
    this.rollbackReason,
    this.quarantineKey,
  });

  final String id;
  final DateTime timestamp;
  final String title;
  final String message;
  final ClientConnectionPhase phase;
  final ClientControllerEventLevel level;
  final ClientControllerEventKind kind;
  final String? profileId;
  final String? operationId;
  final int? step;
  final String? rollbackReason;
  final String? quarantineKey;
}
