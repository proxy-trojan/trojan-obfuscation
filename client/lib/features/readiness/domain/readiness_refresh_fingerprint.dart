import '../../profiles/domain/client_profile.dart';

String buildReadinessRefreshFingerprint({
  required ClientProfile? profile,
  required String storageSummary,
  required String runtimeMode,
  required String runtimeEndpointHint,
}) {
  return <Object?>[
    profile?.id,
    profile?.name,
    profile?.serverHost,
    profile?.serverPort,
    profile?.sni,
    profile?.localSocksPort,
    profile?.verifyTls,
    profile?.hasStoredPassword,
    profile?.updatedAt.toIso8601String(),
    storageSummary,
    runtimeMode,
    runtimeEndpointHint,
  ].join('|');
}
