import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/platform/services/app_runtime_error_store.dart';
import 'package:trojan_pro_client/platform/services/memory_local_state_store.dart';

void main() {
  test('record persists and restore reloads last unhandled app error',
      () async {
    final localState = MemoryLocalStateStore();
    final store = AppRuntimeErrorStore(localStateStore: localState);

    await store.record(
      source: 'zone_guard',
      error: StateError('boom'),
      stackTrace: StackTrace.current,
    );

    final restored = AppRuntimeErrorStore(localStateStore: localState);
    await restored.restore();

    expect(restored.lastUnhandledError, isNotNull);
    expect(restored.lastUnhandledError!.source, 'zone_guard');
    expect(restored.lastUnhandledError!.message, contains('boom'));
  });
}
