import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'l10n/app_localizations.dart';
import 'models.dart';
import 'state/app_state.dart';

/// Tray icon, close-to-tray, autostart and silent start on desktop.
class DesktopShell with TrayListener, WindowListener {
  DesktopShell(this.state);

  final AppState state;
  String _menuSignature = '';
  bool _exiting = false;

  static bool get supported => Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  /// Command-line flag used by the autostart entry.
  static const minimizedFlag = '--minimized';

  Future<void> init({required bool startHidden}) async {
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);
    trayManager.addListener(this);

    launchAtStartup.setup(
      appName: 'SolaHelm',
      appPath: Platform.resolvedExecutable,
      args: const [minimizedFlag],
    );
    // The OS entry is the truth (the user may have removed it in Task Manager).
    try {
      final enabled = await launchAtStartup.isEnabled();
      if (enabled != state.settings.launchAtStartup) state.settings.setLaunchAtStartup(enabled);
    } catch (_) {}
    _lastAutostart = state.settings.launchAtStartup;
    state.settings.addListener(_onSettings);

    await _refreshTray(force: true);
    state.addListener(_refreshTray);

    const options = WindowOptions(title: 'SolaHelm', minimumSize: Size(380, 560));
    await windowManager.waitUntilReadyToShow(options, () async {
      if (startHidden) {
        await windowManager.hide();
      } else {
        await showWindow();
      }
    });
  }

  bool _lastAutostart = false;

  Future<void> _onSettings() async {
    final want = state.settings.launchAtStartup;
    if (want == _lastAutostart) return;
    _lastAutostart = want;
    try {
      want ? await launchAtStartup.enable() : await launchAtStartup.disable();
    } catch (_) {}
  }

  Future<void> showWindow() async {
    await windowManager.show();
    if (await windowManager.isMinimized()) await windowManager.restore();
    await windowManager.focus();
  }

  /// Stops the core (which also restores the system proxy) and quits.
  Future<void> exitApp() async {
    if (_exiting) return;
    _exiting = true;
    state.removeListener(_refreshTray);
    try {
      await state.backend.dispose().timeout(const Duration(seconds: 5));
    } catch (_) {}
    try {
      await trayManager.destroy();
    } catch (_) {}
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
    exit(0);
  }

  // ---- window ----

  @override
  void onWindowClose() {
    if (state.settings.closeToTray && !_exiting) {
      windowManager.hide();
    } else {
      exitApp();
    }
  }

  // ---- tray ----

  @override
  void onTrayIconMouseDown() => showWindow();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  S get _s {
    final code = state.settings.languageCode ?? PlatformDispatcher.instance.locale.languageCode;
    return lookupS(Locale(code == 'ru' ? 'ru' : 'en'));
  }

  String _modeText(S s, ProxyMode m) => switch (m) {
        ProxyMode.tun => s.modeTun,
        ProxyMode.systemProxy => s.modeSystemProxy,
        ProxyMode.portOnly => s.modePortOnly(state.coreStatus.port ?? 7890),
      };

  String _routingText(S s, String m) => switch (m) {
        'global' => s.routingGlobal,
        'direct' => s.routingDirect,
        _ => s.routingRule,
      };

  String _delay(S s, String name) {
    final n = state.leaves[name];
    if (n == null) return '';
    if (n.timedOut) return '  —';
    return n.delayMs == null ? '' : '  ${s.pingMs(n.delayMs!)}';
  }

  Future<void> _refreshTray({bool force = false}) async {
    final s = _s;
    final connected = state.status == LinkStatus.connected;
    final selectors = state.groups.where((g) => g.selectable).toList();

    // Rebuilding the native menu is not free: only do it when something shown changed.
    final sig = [
      state.status,
      state.mode,
      state.routingMode,
      state.settings.languageCode,
      state.subscription?.id,
      state.subscriptions.length,
      for (final g in selectors) '${g.name}=${g.now}:${g.members.map((m) => _delay(s, m)).join()}',
    ].join('|');
    if (!force && sig == _menuSignature) return;
    _menuSignature = sig;

    final status = switch (state.status) {
      LinkStatus.connected => s.statusConnected,
      LinkStatus.connecting => s.statusConnecting,
      LinkStatus.disconnected => s.statusDisconnected,
    };
    final node = state.node;
    final tip = [
      'SolaHelm — $status',
      if (connected) '${state.core.label} · ${_modeText(s, state.mode)}',
      if (connected && node != null) node.name,
    ].join('\n');

    final items = <MenuItem>[
      MenuItem(label: s.trayShow, onClick: (_) => showWindow()),
      MenuItem.separator(),
      MenuItem(
        label: connected || state.status == LinkStatus.connecting ? s.disconnect : s.connect,
        onClick: (_) => state.toggleConnection(),
      ),
      MenuItem.submenu(
        label: s.trayModeMenu(_modeText(s, state.mode)),
        submenu: Menu(items: [
          for (final m in ProxyMode.values)
            MenuItem.checkbox(label: _modeText(s, m), checked: m == state.mode, onClick: (_) => state.setMode(m)),
        ]),
      ),
      if (connected && state.routingMode != null)
        MenuItem.submenu(
          label: s.routingMenu(_routingText(s, state.routingMode!)),
          submenu: Menu(items: [
            for (final m in const ['rule', 'global', 'direct'])
              MenuItem.checkbox(
                label: _routingText(s, m),
                checked: m == state.routingMode,
                onClick: (_) => state.setRoutingMode(m),
              ),
          ]),
        ),
      if (connected && selectors.isNotEmpty) MenuItem.separator(),
      if (connected)
        for (final g in selectors)
          MenuItem.submenu(
            label: '${g.name}:  ${g.now ?? '—'}${g.now == null ? '' : _delay(s, g.now!)}',
            submenu: Menu(items: [
              for (final m in g.members.take(60))
                MenuItem.checkbox(
                  label: '$m${_delay(s, m)}',
                  checked: m == g.now,
                  onClick: (_) => state.selectNodeIn(g.name, m),
                ),
            ]),
          ),
      if (state.subscriptions.isNotEmpty) ...[
        MenuItem.separator(),
        MenuItem.submenu(
          label: s.navSubscriptions,
          submenu: Menu(items: [
            for (final sub in state.subscriptions)
              MenuItem.checkbox(
                label: sub.name,
                checked: sub.id == state.subscription?.id,
                onClick: (_) => state.selectSubscription(sub.id),
              ),
          ]),
        ),
      ],
      MenuItem.separator(),
      MenuItem(label: s.trayExit, onClick: (_) => exitApp()),
    ];

    try {
      await trayManager.setIcon(Platform.isWindows
          ? (connected ? 'assets/tray_on.ico' : 'assets/tray_off.ico')
          : 'assets/icon.png');
      await trayManager.setToolTip(tip);
      await trayManager.setContextMenu(Menu(items: items));
    } catch (_) {
      // No tray on this desktop (e.g. some Linux sessions): the window still works.
    }
  }
}
