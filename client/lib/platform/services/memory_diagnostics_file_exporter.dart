import 'diagnostics_file_exporter.dart';

class MemoryDiagnosticsFileExporter implements DiagnosticsFileExporter {
  final Map<String, String> _exports = <String, String>{};

  @override
  String get backendName => 'memory-diagnostics-export-stub';

  @override
  Future<String> exportText({
    required String fileName,
    required String contents,
  }) async {
    _exports[fileName] = contents;
    return 'memory://diagnostics/$fileName';
  }

  Map<String, String> get exports => Map<String, String>.unmodifiable(_exports);
}
