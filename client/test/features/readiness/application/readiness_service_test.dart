import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/controller/application/fake_client_controller.dart';
import 'package:trojan_pro_client/features/readiness/application/readiness_service.dart';
import 'package:trojan_pro_client/features/readiness/domain/readiness_report.dart';
import 'package:trojan_pro_client/features/profiles/application/profile_secrets_service.dart';
import 'package:trojan_pro_client/features/profiles/application/profile_serialization.dart';
import 'package:trojan_pro_client/features/profiles/application/profile_store.dart';
import 'package:trojan_pro_client/platform/secure_storage/memory_secure_storage.dart';
import 'package:trojan_pro_client/platform/services/memory_local_state_store.dart';

void main() {
  test('readiness blocks when no profile selected', () async {
    final localState = MemoryLocalStateStore();
    final profileStore = ProfileStore(
      initialProfiles: const [],
      localStateStore: localState,
      serialization: ProfileSerialization(),
    );
    final secureStorage = MemorySecureStorage();

    final readiness = ReadinessService(
      profileStore: profileStore,
      profileSecrets: ProfileSecretsService(secureStorage: secureStorage),
      secureStorage: secureStorage,
      controller: FakeClientController(),
    );

    final report = await readiness.buildReport();

    expect(report.overallLevel, ReadinessLevel.blocked);
    expect(report.headline, 'Connect blocked');
    expect(
      report.checks.any(
          (check) => check.domain == ReadinessDomain.profile && check.level == ReadinessLevel.blocked),
      isTrue,
    );
  });

  test('readiness blocks when password is missing for selected profile',
      () async {
    final localState = MemoryLocalStateStore();
    final profileStore = ProfileStore.withSampleProfiles(
      localStateStore: localState,
      serialization: ProfileSerialization(),
    );

    final secureStorage = MemorySecureStorage();
    final readiness = ReadinessService(
      profileStore: profileStore,
      profileSecrets: ProfileSecretsService(secureStorage: secureStorage),
      secureStorage: secureStorage,
      controller: FakeClientController(),
    );

    final report = await readiness.buildReport();

    expect(report.overallLevel, ReadinessLevel.blocked);
    expect(
      report.checks.any(
          (check) => check.domain == ReadinessDomain.password && check.level == ReadinessLevel.blocked),
      isTrue,
    );
  });

  test('readiness is degraded when secure storage is session-only', () async {
    final localState = MemoryLocalStateStore();
    final profileStore = ProfileStore.withSampleProfiles(
      localStateStore: localState,
      serialization: ProfileSerialization(),
    );

    final secureStorage = MemorySecureStorage();
    final profile = profileStore.selectedProfile!;
    final profileSecrets = ProfileSecretsService(secureStorage: secureStorage);
    await profileSecrets.saveTrojanPassword(profileId: profile.id, password: 'pw');
    profileStore.upsertProfile(profile.copyWith(hasStoredPassword: true));

    final readiness = ReadinessService(
      profileStore: profileStore,
      profileSecrets: profileSecrets,
      secureStorage: secureStorage,
      controller: FakeClientController(),
    );

    final report = await readiness.buildReport();

    expect(report.overallLevel, ReadinessLevel.degraded);
    expect(
      report.checks.any((check) =>
          check.domain == ReadinessDomain.secureStorage &&
          check.level == ReadinessLevel.degraded),
      isTrue,
    );
    expect(report.recommendation, isNotNull);
    expect(report.recommendation!.action, ReadinessAction.openTroubleshooting);
  });

  test('recommendation prefers blocked fixes over degraded warnings', () {
    final report = ReadinessReport.fromChecks(
      const <ReadinessCheck>[
        ReadinessCheck(
          domain: ReadinessDomain.secureStorage,
          level: ReadinessLevel.degraded,
          summary: 'secure storage fallback',
          action: ReadinessAction.openTroubleshooting,
          actionLabel: 'Open Troubleshooting',
        ),
        ReadinessCheck(
          domain: ReadinessDomain.password,
          level: ReadinessLevel.blocked,
          summary: 'password missing',
          action: ReadinessAction.openProfiles,
          actionLabel: 'Open Profiles',
        ),
      ],
    );

    expect(report.recommendation, isNotNull);
    expect(report.recommendation!.action, ReadinessAction.openProfiles);
  });

  test('recommendation ordering stays stable across degraded domains', () {
    final report = ReadinessReport.fromChecks(
      const <ReadinessCheck>[
        ReadinessCheck(
          domain: ReadinessDomain.runtimePath,
          level: ReadinessLevel.degraded,
          summary: 'stub runtime path',
          action: ReadinessAction.openTroubleshooting,
          actionLabel: 'Open Troubleshooting',
        ),
        ReadinessCheck(
          domain: ReadinessDomain.secureStorage,
          level: ReadinessLevel.degraded,
          summary: 'secure storage fallback',
          action: ReadinessAction.openTroubleshooting,
          actionLabel: 'Open Troubleshooting',
        ),
      ],
    );

    expect(report.recommendation, isNotNull);
    expect(report.recommendation!.detail, 'secure storage fallback');
  });

  test('readiness persists and restores last-known snapshot', () async {
    final localState = MemoryLocalStateStore();
    final profileStore = ProfileStore.withSampleProfiles(
      localStateStore: localState,
      serialization: ProfileSerialization(),
    );
    final secureStorage = MemorySecureStorage();
    final profile = profileStore.selectedProfile!;
    final profileSecrets = ProfileSecretsService(secureStorage: secureStorage);
    await profileSecrets.saveTrojanPassword(profileId: profile.id, password: 'pw');
    profileStore.upsertProfile(profile.copyWith(hasStoredPassword: true));

    final readiness = ReadinessService(
      profileStore: profileStore,
      profileSecrets: profileSecrets,
      secureStorage: secureStorage,
      controller: FakeClientController(),
      localStateStore: localState,
    );

    final built = await readiness.buildReport();
    final restored = await readiness.readLastKnownReport();

    expect(restored, isNotNull);
    expect(restored!.overallLevel, built.overallLevel);
    expect(restored.summary, built.summary);
    expect(restored.recommendation?.action, built.recommendation?.action);
  });
}
