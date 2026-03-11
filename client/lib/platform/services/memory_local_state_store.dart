import 'local_state_store.dart';

class MemoryLocalStateStore implements LocalStateStore {
  final Map<String, String> _state = <String, String>{};

  @override
  String get backendName => 'memory-state-stub';

  @override
  Future<void> delete(String key) async {
    _state.remove(key);
  }

  @override
  Future<String?> read(String key) async {
    return _state[key];
  }

  @override
  Future<void> write(String key, String value) async {
    _state[key] = value;
  }
}
