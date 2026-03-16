import 'package:flutter_test/flutter_test.dart';
import 'package:trojan_pro_client/platform/services/desktop_lifecycle_models.dart';

void main() {
  test('desktop default policy uses hide-to-tray close behavior', () {
    expect(
      DesktopLifecyclePolicy.desktopDefault.closeBehavior,
      DesktopCloseBehavior.hideToTray,
    );
  });

  test('close summary falls back when tray is unavailable', () {
    final summary = DesktopLifecyclePolicy.desktopDefault.closeSemanticsSummary(
      trayReady: false,
    );
    expect(summary, contains('falls back to minimize'));
  });

  test('quit summary describes explicit app exit path', () {
    final summary =
        DesktopLifecyclePolicy.desktopDefault.quitSemanticsSummary();
    expect(summary, contains('best-effort disconnect'));
    expect(summary, contains('exits'));
  });

  test('duplicate launch summary explains focus-existing-window behavior', () {
    final summary = DesktopLifecyclePolicy.desktopDefault.duplicateLaunchSummary(
      singleInstancePrimary: true,
    );
    expect(summary, contains('file-lock guard'));
    expect(summary, contains('focus the existing window'));
  });

  test('tray policy summary describes expected quick actions', () {
    final summary = DesktopLifecyclePolicy.desktopDefault.trayPolicySummary();
    expect(summary, contains('Open / Connect / Disconnect / Quit'));
  });

  test('external activation headline/guidance are productized for focus IPC', () {
    final status = DesktopLifecycleStatus.initializing().copyWith(
      lastExternalActivationAt: DateTime.parse('2026-03-16T11:00:00.000Z'),
      lastExternalActivationSource: 'secondary-launch-focus-ipc',
    );

    expect(
      status.externalActivationHeadline(),
      'Another launch focused this existing window',
    );
    expect(
      status.externalActivationGuidance(),
      contains('Single-instance mitigation is working'),
    );
  });

  test('recent external activation ages out after timeout window', () {
    final status = DesktopLifecycleStatus.initializing().copyWith(
      lastExternalActivationAt: DateTime.parse('2026-03-16T11:00:00.000Z'),
      lastExternalActivationSource: 'secondary-launch-focus-ipc',
    );

    expect(
      status.isRecentExternalActivation(
        now: DateTime.parse('2026-03-16T11:04:59.000Z'),
      ),
      isTrue,
    );
    expect(
      status.isRecentExternalActivation(
        now: DateTime.parse('2026-03-16T11:05:01.000Z'),
      ),
      isFalse,
    );
  });
}
