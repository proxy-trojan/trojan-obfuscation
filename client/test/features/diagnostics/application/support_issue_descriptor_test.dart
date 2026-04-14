import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/controller/domain/client_connection_status.dart';
import 'package:trojan_pro_client/features/diagnostics/application/support_issue_descriptor.dart';

void main() {
  test('classifies missing password as user input family', () {
    final descriptor = SupportIssueDescriptor.fromConnectionStatus(
      ClientConnectionStatus(
        phase: ClientConnectionPhase.error,
        message: 'MISSING_TROJAN_PASSWORD',
        updatedAt: DateTime.parse('2026-04-14T07:00:00.000Z'),
        activeProfileId: 'profile-demo',
      ),
    );

    expect(descriptor.category, SupportIssueCategory.userInput);
    expect(descriptor.familyLabel, 'user_input');
    expect(descriptor.label, 'User input');
  });

  test('classifies invalid config error as config family', () {
    final descriptor = SupportIssueDescriptor.fromConnectionStatus(
      ClientConnectionStatus(
        phase: ClientConnectionPhase.error,
        message: 'config invalid for runtime launch',
        updatedAt: DateTime.parse('2026-04-14T07:00:00.000Z'),
        activeProfileId: 'profile-demo',
      ),
    );

    expect(descriptor.category, SupportIssueCategory.configuration);
    expect(descriptor.familyLabel, 'config');
    expect(descriptor.headline, 'The runtime config could not be prepared');
    expect(descriptor.guidance, contains('before the runtime could launch'));
  });

  test('classifies unsupported diagnostics export as environment family', () {
    final descriptor = SupportIssueDescriptor.fromConnectionStatus(
      ClientConnectionStatus(
        phase: ClientConnectionPhase.error,
        message: 'UNSUPPORTED',
        updatedAt: DateTime.parse('2026-04-14T07:00:00.000Z'),
        activeProfileId: 'profile-demo',
      ),
    );

    expect(descriptor.category, SupportIssueCategory.runtime);
    expect(descriptor.familyLabel, 'environment');
    expect(descriptor.headline, 'This environment cannot provide that runtime evidence');
  });

  test('classifies runtime exit as connect family', () {
    final descriptor = SupportIssueDescriptor.fromConnectionStatus(
      ClientConnectionStatus(
        phase: ClientConnectionPhase.error,
        message: 'Runtime session exited with code 7.',
        updatedAt: DateTime.parse('2026-04-14T07:00:00.000Z'),
        activeProfileId: 'profile-demo',
      ),
    );

    expect(descriptor.category, SupportIssueCategory.runtime);
    expect(descriptor.familyLabel, 'connect');
    expect(descriptor.summary, 'Runtime session exited with code 7.');
  });

  test('classifies export write failures as export_os family', () {
    final descriptor = SupportIssueDescriptor.fromExportError(
      StateError('permission denied for diagnostics export'),
    );

    expect(descriptor.category, SupportIssueCategory.osOrExport);
    expect(descriptor.familyLabel, 'export_os');
    expect(descriptor.headline, 'The support bundle could not be written');
  });
}
