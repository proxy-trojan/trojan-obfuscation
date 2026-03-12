import 'dart:io';

import 'local_state_store.dart';

class FileBackedLocalStateStore implements LocalStateStore {
  FileBackedLocalStateStore({required String directoryPath})
      : _directory = Directory(directoryPath);

  final Directory _directory;

  @override
  String get backendName => 'desktop-file-state';

  @override
  Future<void> delete(String key) async {
    final file = await _fileFor(key);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<String?> read(String key) async {
    final file = await _fileFor(key);
    if (!await file.exists()) {
      return null;
    }
    return file.readAsString();
  }

  @override
  Future<void> write(String key, String value) async {
    final file = await _fileFor(key);
    await file.writeAsString(value, flush: true);
  }

  Future<File> _fileFor(String key) async {
    final safeKey = _sanitizeSegment(key, label: 'state key');
    await _directory.create(recursive: true);
    return File('${_directory.path}${Platform.pathSeparator}$safeKey');
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
