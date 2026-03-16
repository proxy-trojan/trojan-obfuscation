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
}
