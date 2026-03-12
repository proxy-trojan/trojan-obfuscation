import '../domain/client_profile.dart';

class ProfileImportBundle {
  const ProfileImportBundle({
    required this.profile,
    required this.trojanPasswordIncluded,
    required this.sourceDeviceHadStoredPassword,
    required this.importBehavior,
  });

  final ClientProfile profile;
  final bool trojanPasswordIncluded;
  final bool sourceDeviceHadStoredPassword;
  final String? importBehavior;
}
