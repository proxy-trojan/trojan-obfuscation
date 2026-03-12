abstract class DiagnosticsFileExporter {
  String get backendName;

  Future<String> exportText({
    required String fileName,
    required String contents,
  });
}
