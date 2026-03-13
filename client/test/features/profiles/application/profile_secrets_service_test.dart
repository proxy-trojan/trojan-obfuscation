import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/profiles/application/profile_secrets_service.dart';
import 'package:trojan_pro_client/platform/secure_storage/memory_secure_storage.dart';

void main() {
  test('reports non-secure fallback summary when using memory storage', () async {
    final service = ProfileSecretsService(secureStorage: MemorySecureStorage());

    await service.saveTrojanPassword(profileId: 'demo', password: 'secret');

    expect(service.isSecureStorageReady, isFalse);
    expect(service.storageSummary, contains('Session'));
    expect(await service.hasTrojanPassword('demo'), isTrue);
  });

  test('saveTrojanPassword throws ArgumentError for empty password', () async {
    final service = ProfileSecretsService(secureStorage: MemorySecureStorage());

    expect(
      () => service.saveTrojanPassword(profileId: 'demo', password: ''),
      throwsArgumentError,
    );
    expect(
      () => service.saveTrojanPassword(profileId: 'demo', password: '   '),
      throwsArgumentError,
    );
  });

  test('readTrojanPassword returns null when no password is stored', () async {
    final service = ProfileSecretsService(secureStorage: MemorySecureStorage());

    final result = await service.readTrojanPassword('non-existent');
    expect(result, isNull);
  });

  test('clearTrojanPassword removes stored password', () async {
    final service = ProfileSecretsService(secureStorage: MemorySecureStorage());

    await service.saveTrojanPassword(profileId: 'demo', password: 'secret');
    expect(await service.hasTrojanPassword('demo'), isTrue);

    await service.clearTrojanPassword('demo');
    expect(await service.hasTrojanPassword('demo'), isFalse);
    expect(await service.readTrojanPassword('demo'), isNull);
  });

  test('hasTrojanPassword returns false when not stored', () async {
    final service = ProfileSecretsService(secureStorage: MemorySecureStorage());

    expect(await service.hasTrojanPassword('absent'), isFalse);
  });
}
