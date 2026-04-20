import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/features/readiness/domain/readiness_report.dart';

void main() {
  test('blocked readiness exposes actionable recommendation', () {
    final report = ReadinessReport.fromChecks(
      const <ReadinessCheck>[
        ReadinessCheck(
          domain: ReadinessDomain.password,
          level: ReadinessLevel.blocked,
          summary: 'password missing',
          detail: 'Set Trojan password before first connect.',
          action: ReadinessAction.openProfiles,
          actionLabel: 'Open Profiles',
        ),
      ],
    );

    expect(report.overallLevel, ReadinessLevel.blocked);
    expect(report.recommendation, isNotNull);
    expect(report.recommendation!.label, 'Open Profiles');
    expect(report.recommendation!.detail, contains('Set Trojan password'));
  });
}
