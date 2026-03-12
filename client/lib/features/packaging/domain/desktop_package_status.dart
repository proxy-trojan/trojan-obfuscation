enum DesktopPackagePlatform {
  windows,
  macos,
  linux,
}

enum DesktopPackageReadiness {
  planned,
  scaffolded,
  validated,
}

class DesktopPackageStatus {
  const DesktopPackageStatus({
    required this.platform,
    required this.readiness,
    required this.notes,
  });

  final DesktopPackagePlatform platform;
  final DesktopPackageReadiness readiness;
  final String notes;
}
