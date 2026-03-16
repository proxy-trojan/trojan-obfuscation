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
    DesktopConnectHandler? onConnectRequested,
    DesktopDisconnectHandler? onDisconnectRequested,
    this.trayToolTip = 'Trojan Pro Client',
    this.trayPngAssetPath = 'assets/tray/tray_icon.png',
    this.trayIcoAssetPath = 'assets/tray/tray_icon.ico',
  })  : _policy = policy,
        _onQuitRequested = onQuitRequested,
        _singleInstancePrimary = singleInstancePrimary,
        _onConnectRequested = onConnectRequested,
        _onDisconnectRequested = onDisconnectRequested;

  DesktopLifecyclePolicy _policy;
  final DesktopQuitHandler _onQuitRequested;
  final bool _singleInstancePrimary;
  final DesktopConnectHandler? _onConnectRequested;
  final DesktopDisconnectHandler? _onDisconnectRequested;
  final String trayToolTip;
  final String trayPngAssetPath;
  final String trayIcoAssetPath;

  DesktopLifecycleStatus _status = DesktopLifecycleStatus.initializing();
  DesktopQuickActionsState _quickActions = DesktopQuickActionsState.initial;
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
  DesktopQuickActionsState get quickActions => _quickActions;

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
    await _setupTrayIfEnabled();

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
  Future<void> applyPolicy(DesktopLifecyclePolicy policy) async {
    _policy = policy;

    if (!_initialized || !isDesktopPlatform()) {
      _status = _status.copyWith(summary: _composeSummary());
      _notifyIfActive();
      return;
    }

    await _applyCloseInterceptionPolicy();
    if (_policy.enableTrayQuickActions) {
      if (!_trayReady) {
        await _setupTrayIfEnabled();
      } else {
        await _refreshTrayMenu();
      }
    } else {
      await _teardownTray();
    }

    _status = _status.copyWith(
      trayReady: _trayReady,
      closeInterceptEnabled: _closeInterceptEnabled,
      summary: _composeSummary(),
    );
    _notifyIfActive();
  }

  @override
  Future<void> updateQuickActions(DesktopQuickActionsState state) async {
    _quickActions = state;
    if (_trayReady) {
      await _refreshTrayMenu();
    }

    _status = _status.copyWith(summary: _composeSummary());
    _notifyIfActive();
  }

  @override
  Future<void> recordExternalActivation({required String source}) async {
    _status = _status.copyWith(
      lastExternalActivationAt: DateTime.now(),
      lastExternalActivationSource: source,
      summary: _composeSummary(),
    );
    _notifyIfActive();
  }

  @override
  Future<void> clearExternalActivation() async {
    _status = _status.copyWith(
      clearLastExternalActivation: true,
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

    await _teardownTray();

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

    await _teardownTray();

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
      case 'connect_selected':
        if (_quickActions.canConnect) {
          unawaited(_handleConnectRequested());
        }
        return;
      case 'disconnect_active':
        if (_quickActions.canDisconnect) {
          unawaited(_handleDisconnectRequested());
        }
        return;
      case 'quit_app':
        unawaited(requestQuit());
        return;
      default:
        return;
    }
  }

  Future<void> _handleConnectRequested() async {
    final callback = _onConnectRequested;
    if (callback == null) return;
    try {
      await callback();
    } catch (error) {
      debugPrint('DesktopLifecycleService: tray connect failed: $error');
    }
  }

  Future<void> _handleDisconnectRequested() async {
    final callback = _onDisconnectRequested;
    if (callback == null) return;
    try {
      await callback();
    } catch (error) {
      debugPrint('DesktopLifecycleService: tray disconnect failed: $error');
    }
  }

  Future<void> _applyCloseInterceptionPolicy() async {
    _closeInterceptEnabled =
        _policy.closeBehavior != DesktopCloseBehavior.quitApplication;
    await windowManager.setPreventClose(_closeInterceptEnabled);
  }

  Future<void> _setupTrayIfEnabled() async {
    if (!_policy.enableTrayQuickActions) {
      _trayReady = false;
      return;
    }

    try {
      await trayManager.setIcon(_resolveTrayIconPath());
      await trayManager.setToolTip(trayToolTip);
      await _refreshTrayMenu();
      trayManager.addListener(this);
      _trayReady = true;
    } catch (error) {
      _trayReady = false;
      debugPrint('DesktopLifecycleService: tray init failed: $error');
    }
  }

  Future<void> _refreshTrayMenu() async {
    final selectedProfileName = _quickActions.selectedProfileName;
    final connectLabel =
        selectedProfileName == null || selectedProfileName.isEmpty
            ? 'Connect'
            : 'Connect (${_truncateLabel(selectedProfileName)})';

    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(
            key: 'open_window',
            label: 'Open',
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'connect_selected',
            label: connectLabel,
            disabled: !_quickActions.canConnect,
          ),
          MenuItem(
            key: 'disconnect_active',
            label: 'Disconnect',
            disabled: !_quickActions.canDisconnect,
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'quit_app',
            label: 'Quit',
          ),
        ],
      ),
    );
  }

  String _truncateLabel(String input) {
    const maxLength = 26;
    if (input.length <= maxLength) {
      return input;
    }
    return '${input.substring(0, maxLength - 1)}…';
  }

  Future<void> _teardownTray() async {
    if (!_trayReady) return;
    trayManager.removeListener(this);
    try {
      await trayManager.destroy();
    } catch (_) {
      // best-effort tray cleanup
    }
    _trayReady = false;
  }

  String _resolveTrayIconPath() {
    if (Platform.isWindows) {
      return trayIcoAssetPath;
    }
    return trayPngAssetPath;
  }

  String _composeSummary() {
    final closeSummary = _policy.closeSemanticsSummary(trayReady: _trayReady);
    final duplicateSummary = _policy.duplicateLaunchSummary(
      singleInstancePrimary: _singleInstancePrimary,
    );
    final quickActionSummary = _quickActions.readinessSummary(
      trayReady: _trayReady,
    );
    return '$closeSummary $duplicateSummary $quickActionSummary';
  }

  void _notifyIfActive() {
    if (_disposed) return;
    notifyListeners();
  }
}
