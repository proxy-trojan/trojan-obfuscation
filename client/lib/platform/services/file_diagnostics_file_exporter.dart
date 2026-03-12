import 'dart:io';

import 'diagnostics_file_exporter.dart';

class FileDiagnosticsFileExporter implements DiagnosticsFileExporter {
  FileDiagnosticsFileExporter({required String directoryPath})
      : _directory = Directory(directoryPath);

  final Directory _directory;

  @override
  String get backendName => 'desktop-file-export';

  @override
  Future<String> exportText({
    required String fileName,
    required String contents,
  }) async {
    final safeFileName = _sanitizeSegment(fileName, label: 'diagnostics file name');
    await _directory.create(recursive: true);
    final file = File('${_directory.path}${Platform.pathSeparator}$safeFileName');
    await file.writeAsString(contents, flush: true);
    return file.uri.toString();
  }

  String _sanitizeSegment(String value, {required String label}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('$label cannot be empty');
    }
    if (trimmed.contains('..') || trimmed.contains('/') || trimmed.contains('\\')) {
      throw ArgumentError('$label must not contain path separators or parent traversal');
    }
    return trimmed;
  }
}
