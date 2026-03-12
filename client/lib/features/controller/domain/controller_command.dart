enum ControllerCommandKind {
  connect,
  disconnect,
  collectDiagnostics,
  prepareExport,
}

class ControllerCommand {
  const ControllerCommand({
    required this.id,
    required this.kind,
    required this.issuedAt,
    this.profileId,
    this.arguments = const <String, Object?>{},
    this.secretArguments = const <String, String>{},
  });

  final String id;
  final ControllerCommandKind kind;
  final DateTime issuedAt;
  final String? profileId;
  final Map<String, Object?> arguments;
  final Map<String, String> secretArguments;
}
