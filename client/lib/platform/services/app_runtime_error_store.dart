import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'local_state_store.dart';

class AppUnhandledErrorSummary {
  const AppUnhandledErrorSummary({
    required this.source,
    required this.message,
    required this.stackPreview,
    required this.recordedAt,
  });

  final String source;
  final String message;
  final String stackPreview;
  final DateTime recordedAt;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'source': source,
      'message': message,
      'stackPreview': stackPreview,
      'recordedAt': recordedAt.toIso8601String(),
    };
  }

  static AppUnhandledErrorSummary? fromJson(Object? value) {
    if (value is! Map) return null;
    final source = value['source'];
    final message = value['message'];
    final stackPreview = value['stackPreview'];
    final recordedAt = value['recordedAt'];
    if (source is! String ||
        message is! String ||
        stackPreview is! String ||
        recordedAt is! String) {
      return null;
    }
    final parsed = DateTime.tryParse(recordedAt);
    if (parsed == null) return null;
    return AppUnhandledErrorSummary(
      source: source,
      message: message,
      stackPreview: stackPreview,
      recordedAt: parsed,
    );
  }
}

class AppRuntimeErrorStore extends ChangeNotifier {
  AppRuntimeErrorStore({LocalStateStore? localStateStore})
      : _localStateStore = localStateStore;

  static const String _storageKey = 'app.lastUnhandledErrorSummary';

  final LocalStateStore? _localStateStore;
  AppUnhandledErrorSummary? _lastUnhandledError;

  AppUnhandledErrorSummary? get lastUnhandledError => _lastUnhandledError;

  Future<void> restore() async {
    final store = _localStateStore;
    if (store == null) return;
    final raw = await store.read(_storageKey);
    if (raw == null || raw.trim().isEmpty) return;
    try {
      _lastUnhandledError = AppUnhandledErrorSummary.fromJson(jsonDecode(raw));
      notifyListeners();
    } catch (_) {
      // ignore corrupted persisted payloads
    }
  }

  Future<void> record({
    required String source,
    required Object error,
    StackTrace? stackTrace,
  }) async {
    final summary = AppUnhandledErrorSummary(
      source: source,
      message: error.toString(),
      stackPreview: _stackPreview(stackTrace),
      recordedAt: DateTime.now(),
    );
    _lastUnhandledError = summary;
    await _persist();
    notifyListeners();
  }

  Future<void> clear() async {
    _lastUnhandledError = null;
    final store = _localStateStore;
    if (store != null) {
      await store.delete(_storageKey);
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    final store = _localStateStore;
    final summary = _lastUnhandledError;
    if (store == null || summary == null) return;
    await store.write(_storageKey, jsonEncode(summary.toJson()));
  }

  String _stackPreview(StackTrace? stackTrace) {
    if (stackTrace == null) return 'no stack trace captured';
    final lines = stackTrace.toString().trim().split('\n');
    return lines.take(6).join('\n');
  }
}
