import '../../controller/domain/client_connection_status.dart';
import '../../controller/domain/failure_family.dart';

enum SupportIssueCategory {
  userInput,
  configuration,
  runtime,
  osOrExport,
  none,
}

class SupportIssueDescriptor {
  const SupportIssueDescriptor({
    required this.category,
    required this.family,
    required this.label,
    required this.headline,
    required this.guidance,
    required this.summary,
  });

  final SupportIssueCategory category;
  final FailureFamily family;
  final String label;
  final String headline;
  final String guidance;
  final String summary;

  String get familyLabel => family.label;

  static SupportIssueDescriptor fromConnectionStatus(
    ClientConnectionStatus status,
  ) {
    final message = status.message.trim();

    if (status.phase != ClientConnectionPhase.error) {
      return SupportIssueDescriptor(
        category: SupportIssueCategory.none,
        family: FailureFamily.unknown,
        label: 'No active issue',
        headline: 'No support issue is active right now',
        guidance:
            'Use Problem Report when a connection attempt fails or you need a support-ready snapshot.',
        summary: message,
      );
    }

    final family = classifyFailureFamily(
      errorCode: message,
      summary: message,
      detail: message,
    );

    return switch (family) {
      FailureFamily.userInput => const SupportIssueDescriptor(
          category: SupportIssueCategory.userInput,
          family: FailureFamily.userInput,
          label: 'User input',
          headline: 'A required password is still missing',
          guidance:
              'Open Profiles, save the Trojan password, then retry the connection attempt.',
          summary: 'Trojan password is missing for the selected profile.',
        ),
      FailureFamily.config => const SupportIssueDescriptor(
          category: SupportIssueCategory.configuration,
          family: FailureFamily.config,
          label: 'Configuration',
          headline: 'The runtime config could not be prepared',
          guidance:
              'Review the selected profile fields and config inputs before the runtime could launch. If the issue persists, export a support bundle.',
          summary: 'Config preparation failed before launch.',
        ),
      FailureFamily.environment => const SupportIssueDescriptor(
          category: SupportIssueCategory.runtime,
          family: FailureFamily.environment,
          label: 'Environment',
          headline: 'This environment cannot provide that runtime evidence',
          guidance:
              'Check the current controller posture or host capability first. If you still need a record, export a support bundle with the current environment details.',
          summary: 'Runtime evidence is unavailable on this environment.',
        ),
      FailureFamily.connect => SupportIssueDescriptor(
          category: SupportIssueCategory.runtime,
          family: FailureFamily.connect,
          label: 'Connect path',
          headline: 'The runtime session stopped unexpectedly',
          guidance:
              'Retry the connection if you want another attempt, or export a support bundle for investigation.',
          summary: message.isEmpty ? 'Connect path failed after launch.' : message,
        ),
      FailureFamily.exportOs => SupportIssueDescriptor(
          category: SupportIssueCategory.osOrExport,
          family: FailureFamily.exportOs,
          label: 'Export / OS',
          headline: 'The support bundle could not be written',
          guidance:
              'Check the export target path and local file permissions, then try the export again.',
          summary: message.isEmpty ? 'Diagnostics export failed.' : message,
        ),
      FailureFamily.launch || FailureFamily.unknown => SupportIssueDescriptor(
          category: SupportIssueCategory.runtime,
          family: family,
          label: family == FailureFamily.launch ? 'Launch' : 'Runtime',
          headline: family == FailureFamily.launch
              ? 'The connection could not start'
              : 'The last connection needs runtime troubleshooting',
          guidance: family == FailureFamily.launch
              ? 'Open Problem Report if you want a support-ready snapshot of the failed launch attempt.'
              : 'Open Problem Report if you want to share a support-ready snapshot with the latest details.',
          summary: message.isEmpty ? 'Connection failed.' : message,
        ),
    };
  }

  static SupportIssueDescriptor fromExportError(Object error) {
    final message = error.toString().trim();
    return SupportIssueDescriptor(
      category: SupportIssueCategory.osOrExport,
      family: FailureFamily.exportOs,
      label: 'Export / OS',
      headline: 'The support bundle could not be written',
      guidance:
          'Check the export target path and local file permissions, then try the export again.',
      summary: message.isEmpty ? 'Diagnostics export failed.' : message,
    );
  }
}
