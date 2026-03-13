import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/profiles/application/profile_serialization.dart';
import 'package:trojan_pro_client/features/profiles/application/profile_store.dart';
import 'package:trojan_pro_client/features/profiles/domain/client_profile.dart';
import 'package:trojan_pro_client/platform/services/memory_local_state_store.dart';

ClientProfile _profile({
  String id = 'profile-1',
  String name = 'Profile One',
  bool hasStoredPassword = false,
}) {
  return ClientProfile(
    id: id,
    name: name,
    serverHost: 'example.com',
    serverPort: 443,
    sni: 'example.com',
    localSocksPort: 1080,
    verifyTls: true,
    updatedAt: DateTime.parse('2026-03-13T00:00:00.000Z'),
    hasStoredPassword: hasStoredPassword,
  );
}

void main() {
  test('upsertProfile persists profile list into local state store', () async {
    final localState = MemoryLocalStateStore();
    final store = ProfileStore(
      initialProfiles: const <ClientProfile>[],
      localStateStore: localState,
      serialization: ProfileSerialization(),
    );

    final profile = _profile(id: 'persist-1', name: 'Persisted Profile');
    store.upsertProfile(profile);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final raw = await localState.read('profiles.json');
    expect(raw, isNotNull);
    expect(raw, contains('"id": "persist-1"'));
    expect(raw, contains('"name": "Persisted Profile"'));
  });

  test('load restores profiles from local state store payload', () async {
    final localState = MemoryLocalStateStore();
    final serialization = ProfileSerialization();
    final payload = serialization.encodeProfileList(<ClientProfile>[
      _profile(id: 'load-1', name: 'Loaded One'),
      _profile(id: 'load-2', name: 'Loaded Two'),
    ]);
    await localState.write('profiles.json', payload);

    final store = ProfileStore(
      initialProfiles: const <ClientProfile>[],
      localStateStore: localState,
      serialization: serialization,
    );

    await store.load();

    expect(store.loaded, isTrue);
    expect(store.profiles.length, 2);
    expect(store.profiles.first.id, 'load-1');
    expect(store.selectedProfileId, 'load-1');
  });

  test('syncStoredPasswordFlags updates hasStoredPassword and persists',
      () async {
    final localState = MemoryLocalStateStore();
    final store = ProfileStore(
      initialProfiles: <ClientProfile>[
        _profile(id: 'p-1', name: 'One', hasStoredPassword: false),
        _profile(id: 'p-2', name: 'Two', hasStoredPassword: false),
      ],
      localStateStore: localState,
      serialization: ProfileSerialization(),
    );

    await store.syncStoredPasswordFlags(<String, bool>{
      'p-1': true,
      'p-2': false,
    });

    final p1 = store.profiles.firstWhere((p) => p.id == 'p-1');
    final p2 = store.profiles.firstWhere((p) => p.id == 'p-2');
    expect(p1.hasStoredPassword, isTrue);
    expect(p2.hasStoredPassword, isFalse);

    final raw = await localState.read('profiles.json');
    expect(raw, contains('"id": "p-1"'));
    expect(raw, contains('"hasStoredPassword": true'));
  });
}
