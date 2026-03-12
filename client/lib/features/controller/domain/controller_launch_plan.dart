class ControllerLaunchPlan {
  const ControllerLaunchPlan({
    required this.binaryPath,
    required this.configPath,
    required this.arguments,
    required this.summary,
  });

  final String binaryPath;
  final String configPath;
  final List<String> arguments;
  final String summary;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'binaryPath': binaryPath,
      'configPath': configPath,
      'arguments': arguments,
      'summary': summary,
    };
  }
}
