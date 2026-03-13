import '../../controller/domain/client_connection_status.dart';

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
    required this.label,
    required this.headline,
    required this.guidance,
    required this.summary,
  });

  final SupportIssueCategory category;
  final String label;
  final String headline;
  final String guidance;
  final String summary;

  static SupportIssueDescriptor fromConnectionStatus(
    ClientConnectionStatus status,
  ) {
    final message = status.message.trim();

    if (status.phase != ClientConnectionPhase.error) {
      return SupportIssueDescriptor(
        category: SupportIssueCategory.none,
        label: 'No active issue',
        headline: 'No support issue is active right now',
        guidance:
            'Use Problem Report when a connection attempt fails or you need a support-ready snapshot.',
        summary: message,
      );
    }

    if (message == 'MISSING_TROJAN_PASSWORD' ||
        message.contains('no Trojan password')) {
      return const SupportIssueDescriptor(
        category: SupportIssueCategory.userInput,
        label: 'User input',
        headline: 'A required password is still missing',
        guidance:
            'Open Profiles, save the Trojan password, then retry the connection attempt.',
        summary: 'Trojan password is missing for the selected profile.',
      );
    }

    if (message.contains('config') && message.contains('invalid')) {
      return const SupportIssueDescriptor(
        category: SupportIssueCategory.configuration,
        label: 'Configuration',
        headline: 'The client could not prepare a valid launch configuration',
        guidance:
            'Review the selected profile fields before trying again. If the issue persists, export a support bundle.',
        summary: 'Runtime launch configuration is not valid.',
      );
    }

    if (message.contains('Runtime session exited with code') ||
        message.contains('Runtime session stopped with error')) {
      return SupportIssueDescriptor(
        category: SupportIssueCategory.runtime,
        label: 'Runtime',
        headline: 'The runtime session stopped unexpectedly',
        guidance:
            'Retry the connection if you want another attempt, or export a support bundle for investigation.',
        summary: message,
      );
    }

    return SupportIssueDescriptor(
      category: SupportIssueCategory.runtime,
      label: 'Runtime',
      headline: 'The last connection needs runtime troubleshooting',
      guidance:
          'Open Problem Report if you want to share a support-ready snapshot with the latest details.',
      summary: message.isEmpty ? 'Connection failed.' : message,
    );
  }

  static SupportIssueDescriptor fromExportError(Object error) {
    final message = error.toString().trim();
    return SupportIssueDescriptor(
      category: SupportIssueCategory.osOrExport,
      label: 'Export / OS',
      headline: 'The support bundle could not be written',
      guidance:
          'Check the export target path and local file permissions, then try the export again.',
      summary: message.isEmpty ? 'Diagnostics export failed.' : message,
    );
  }
}
