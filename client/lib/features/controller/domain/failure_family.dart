enum FailureFamily {
  launch,
  config,
  environment,
  connect,
  userInput,
  exportOs,
  unknown,
}

extension FailureFamilyLabel on FailureFamily {
  String get label => switch (this) {
        FailureFamily.launch => 'launch',
        FailureFamily.config => 'config',
        FailureFamily.environment => 'environment',
        FailureFamily.connect => 'connect',
        FailureFamily.userInput => 'user_input',
        FailureFamily.exportOs => 'export_os',
        FailureFamily.unknown => 'unknown',
      };

  String get displayLabel => switch (this) {
        FailureFamily.launch => 'Launch',
        FailureFamily.config => 'Configuration',
        FailureFamily.environment => 'Environment',
        FailureFamily.connect => 'Connect',
        FailureFamily.userInput => 'User input',
        FailureFamily.exportOs => 'Export / OS',
        FailureFamily.unknown => 'Unknown',
      };
}

FailureFamily parseFailureFamily(Object? value) {
  if (value is! String) return FailureFamily.unknown;
  return switch (value.trim()) {
    'launch' => FailureFamily.launch,
    'config' => FailureFamily.config,
    'environment' => FailureFamily.environment,
    'connect' => FailureFamily.connect,
    'user_input' => FailureFamily.userInput,
    'export_os' => FailureFamily.exportOs,
    _ => FailureFamily.unknown,
  };
}

FailureFamily classifyFailureFamily({
  String? errorCode,
  String? summary,
  String? detail,
  String? phase,
}) {
  final code = (errorCode ?? '').trim().toUpperCase();
  final combined = <String>[summary ?? '', detail ?? '', errorCode ?? '']
      .join(' ')
      .trim()
      .toLowerCase();
  final normalizedPhase = (phase ?? '').trim().toLowerCase();

  bool containsAny(List<String> needles) {
    return needles.any(combined.contains);
  }

  if (code == 'MISSING_TROJAN_PASSWORD' ||
      containsAny(<String>['missing_trojan_password', 'no trojan password'])) {
    return FailureFamily.userInput;
  }

  if (containsAny(<String>[
    'permission denied',
    'could not be written',
    'diagnostics export failed',
    'export failed',
  ])) {
    return FailureFamily.exportOs;
  }

  if (code == 'UNSUPPORTED' ||
      containsAny(<String>[
        'unsupported',
        'does not expose runtime diagnostics',
        'does not expose export preparation',
        'cannot provide that runtime evidence',
      ])) {
    return FailureFamily.environment;
  }

  if (containsAny(<String>[
    'config invalid',
    'invalid config',
    'could not prepare a valid runtime configuration',
    'could not prepare a valid launch configuration',
    'config preparation failed',
  ])) {
    return FailureFamily.config;
  }

  if (normalizedPhase == 'runtime') {
    return FailureFamily.connect;
  }

  if (containsAny(<String>[
    'runtime session exited with code',
    'runtime session stopped with error',
    'runtime session ended unexpectedly',
    'connect path failed after launch',
  ])) {
    return FailureFamily.connect;
  }

  if (normalizedPhase == 'launch') {
    return FailureFamily.launch;
  }

  if (containsAny(<String>[
    'failed to execute trojan client launch plan',
    'launch request rejected',
    'the connection could not start',
  ])) {
    return FailureFamily.launch;
  }

  return FailureFamily.unknown;
}
