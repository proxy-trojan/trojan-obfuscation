import '../../settings/domain/app_settings.dart';
import 'desktop_package_status.dart';

class ReleaseManifest {
  const ReleaseManifest({
    required this.versionLabel,
    required this.channel,
    required this.generatedAt,
    required this.artifactPrefix,
    required this.platforms,
    required this.rollbackHint,
  });

  final String versionLabel;
  final UpdateChannel channel;
  final DateTime generatedAt;
  final String artifactPrefix;
  final List<DesktopPackageStatus> platforms;
  final String rollbackHint;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'versionLabel': versionLabel,
      'channel': channel.name,
      'generatedAt': generatedAt.toIso8601String(),
      'artifactPrefix': artifactPrefix,
      'rollbackHint': rollbackHint,
      'platforms': platforms
          .map(
            (status) => <String, Object?>{
              'platform': status.platform.name,
              'readiness': status.readiness.name,
              'notes': status.notes,
            },
          )
          .toList(),
    };
  }
}
