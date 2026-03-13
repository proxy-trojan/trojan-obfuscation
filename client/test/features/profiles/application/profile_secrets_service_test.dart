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
}
