import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'desktop_lifecycle_models.dart';
import 'desktop_lifecycle_service.dart';

class PluginDesktopLifecycleService extends DesktopLifecycleService
    with WindowListener, TrayListener {
  PluginDesktopLifecycleService({
    required DesktopLifecyclePolicy policy,
    required DesktopQuitHandler onQuitRequested,
    required bool singleInstancePrimary,
    this.trayToolTip = 'Trojan Pro Client',
    this.trayPngAssetPath = 'assets/tray/tray_icon.png',
    this.trayIcoAssetPath = 'assets/tray/tray_icon.ico',
  })  : _policy = policy,
        _onQuitRequested = onQuitRequested,
        _singleInstancePrimary = singleInstancePrimary;

  final DesktopLifecyclePolicy _policy;
  final DesktopQuitHandler _onQuitRequested;
  final bool _singleInstancePrimary;
  final String trayToolTip;
  final String trayPngAssetPath;
  final String trayIcoAssetPath;

  DesktopLifecycleStatus _status = DesktopLifecycleStatus.initializing();
  bool _trayReady = false;
  bool _closeInterceptEnabled = false;
  bool _initialized = false;
  bool _disposed = false;
  bool _quitting = false;

  @override
  DesktopLifecyclePolicy get policy => _policy;

  @override
  DesktopLifecycleStatus get status => _status;

  @override
  Future<void> initialize() async {
    if (_initialized || _disposed) return;

    if (!isDesktopPlatform()) {
      _status = DesktopLifecycleStatus.unsupported();
      _notifyIfActive();
      return;
    }

    _status = DesktopLifecycleStatus.initializing().copyWith(
      singleInstancePrimary: _singleInstancePrimary,
      summary: 'Desktop lifecycle service is initializing.',
    );
    _notifyIfActive();

    await windowManager.ensureInitialized();
    windowManager.addListener(this);

    await _applyCloseInterceptionPolicy();
    await _setupTrayFirstCut();

    _initialized = true;
    _status = DesktopLifecycleStatus(
      supported: true,
      initialized: true,
      trayReady: _trayReady,
      singleInstancePrimary: _singleInstancePrimary,
      closeInterceptEnabled: _closeInterceptEnabled,
      summary: _composeSummary(),
    );
    _notifyIfActive();
  }

  @override
  Future<void> showMainWindow() async {
    if (!isDesktopPlatform()) return;
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  Future<void> minimizeMainWindow() async {
    if (!isDesktopPlatform()) return;
    await windowManager.minimize();
  }

  @override
  Future<void> requestQuit() async {
    if (!isDesktopPlatform()) return;
    if (_quitting) return;
    _quitting = true;

    try {
      await _onQuitRequested();
    } catch (error) {
      debugPrint('DesktopLifecycleService: quit preflight failed: $error');
    }

    if (_trayReady) {
      try {
        await trayManager.destroy();
      } catch (_) {
        // best-effort tray cleanup
      }
    }

    if (_closeInterceptEnabled) {
      try {
        await windowManager.setPreventClose(false);
      } catch (_) {
        // best-effort shutdown
      }
    }

    await windowManager.close();
  }

  @override
  Future<void> disposeService() async {
    if (_disposed) return;
    _disposed = true;

    if (_trayReady) {
      trayManager.removeListener(this);
      try {
        await trayManager.destroy();
      } catch (_) {
        // best-effort tray cleanup
      }
    }

    if (isDesktopPlatform()) {
      windowManager.removeListener(this);
    }
  }

  @override
  void onWindowClose() {
    if (_quitting) {
      return;
    }

    switch (_policy.closeBehavior) {
      case DesktopCloseBehavior.hideToTray:
        if (_trayReady) {
          unawaited(windowManager.hide());
        } else {
          unawaited(windowManager.minimize());
        }
        return;
      case DesktopCloseBehavior.minimizeWindow:
        unawaited(windowManager.minimize());
        return;
      case DesktopCloseBehavior.quitApplication:
        unawaited(requestQuit());
        return;
    }
  }

  @override
  void onTrayIconMouseDown() {
    unawaited(trayManager.popUpContextMenu());
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'open_window':
        unawaited(showMainWindow());
        return;
      case 'quit_app':
        unawaited(requestQuit());
        return;
      default:
        return;
    }
  }

  Future<void> _applyCloseInterceptionPolicy() async {
    _closeInterceptEnabled =
        _policy.closeBehavior != DesktopCloseBehavior.quitApplication;
    await windowManager.setPreventClose(_closeInterceptEnabled);
  }

  Future<void> _setupTrayFirstCut() async {
    if (!_policy.enableTrayQuickActions) {
      _trayReady = false;
      return;
    }

    try {
      await trayManager.setIcon(_resolveTrayIconPath());
      await trayManager.setToolTip(trayToolTip);
      await trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(
              key: 'open_window',
              label: 'Open',
            ),
            MenuItem.separator(),
            MenuItem(
              key: 'quit_app',
              label: 'Quit',
            ),
          ],
        ),
      );
      trayManager.addListener(this);
      _trayReady = true;
    } catch (error) {
      _trayReady = false;
      debugPrint('DesktopLifecycleService: tray init failed: $error');
    }
  }

  String _resolveTrayIconPath() {
    if (Platform.isWindows) {
      return trayIcoAssetPath;
    }
    return trayPngAssetPath;
  }

  String _composeSummary() {
    final closeSummary = _policy.closeSemanticsSummary(trayReady: _trayReady);
    final duplicateSummary = _singleInstancePrimary
        ? 'Single-instance lock is active for this process.'
        : 'Secondary instance detected; this process should exit early.';
    return '$closeSummary $duplicateSummary';
  }

  void _notifyIfActive() {
    if (_disposed) return;
    notifyListeners();
  }
}
