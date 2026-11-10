import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../models.dart';

/// True when a `portable.txt` file sits next to the executable: then all data
/// lives in a `userdata` folder beside it and nothing is written to the profile.
bool get isPortable {
  if (Platform.isAndroid || Platform.isIOS) return false;
  try {
    final dir = File(Platform.resolvedExecutable).parent.path;
    return File('$dir${Platform.pathSeparator}portable.txt').existsSync();
  } catch (_) {
    return false;
  }
}

/// %APPDATA%\solahelm-client, ~/.config/solahelm-client, the app's files dir
/// on Android, or `<exe dir>/userdata` in portable mode. Holds ui.json,
/// subscriptions and the cores' state.
Directory? appDataDir() {
  try {
    if (isPortable) {
      final dir = File(Platform.resolvedExecutable).parent.path;
      return Directory('$dir${Platform.pathSeparator}userdata');
    }
    final env = Platform.environment;
    String? base;
    if (Platform.isWindows) {
      base = env['APPDATA'];
    } else if (Platform.isAndroid) {
      // systemTemp is <app data>/cache; keep data in <app data>/files.
      base = '${Directory.systemTemp.parent.path}/files';
    } else if (Platform.isMacOS) {
      base = '${env['HOME']}/Library/Application Support';
    } else {
      base = env['XDG_CONFIG_HOME'] ?? '${env['HOME']}/.config';
    }
    if (base == null) return null;
    return Directory('$base${Platform.pathSeparator}solahelm-client');
  } catch (_) {
    return null;
  }
}

/// Connection and core settings applied on top of every profile.
@immutable
class CoreSettings {
  const CoreSettings({
    this.manageTun = false,
    this.tunStack = 'gvisor',
    this.strictRoute = true,
    this.mtu = 1500,
    this.routeExclude = defaultRouteExclude,
    this.proxyBypass = defaultProxyBypass,
    this.mixedPort = 7890,
    this.allowLan = false,
    this.ipv6 = 'profile',
    this.logLevel = '',
    this.findProcess = true,
    this.dnsOverride = false,
    this.dnsRemote = defaultDnsRemote,
    this.dnsDirect = defaultDnsDirect,
    this.linkRouting = routingRuDirect,
  });

  /// Routing templates for subscriptions made of links (they carry no rules).
  static const routingAll = 'all';
  static const routingRuDirect = 'ru-direct';

  static const defaultDnsRemote = ['https://1.1.1.1/dns-query', 'https://8.8.8.8/dns-query'];
  static const defaultDnsDirect = ['77.88.8.8', '1.1.1.1'];

  static const defaultRouteExclude = [
    '10.0.0.0/8', '100.64.0.0/10', '169.254.0.0/16', '172.16.0.0/12', '192.168.0.0/16',
  ];
  static const defaultProxyBypass = [
    'localhost', '127.*', '10.*', '172.16.*', '172.17.*', '172.18.*', '172.19.*', '172.2*', '172.30.*',
    '172.31.*', '192.168.*', '<local>',
  ];

  final bool manageTun; // off: the profile's TUN settings (only the stack is ours)
  final String tunStack; // gvisor, mixed, system
  final bool strictRoute;
  final int mtu;
  final List<String> routeExclude; // CIDRs that bypass the tunnel
  final List<String> proxyBypass; // system proxy exceptions
  final int mixedPort; // preferred local port; the next free one is used if busy
  final bool allowLan; // let other devices use the local port
  final String ipv6; // profile, on, off
  final String logLevel; // '' = profile, debug, info, warning, error, silent
  final bool findProcess;
  final bool dnsOverride; // replace a mihomo profile's DNS
  final List<String> dnsRemote; // through the tunnel (respect-rules)
  final List<String> dnsDirect; // for proxy servers and direct traffic
  final String linkRouting; // routingAll or routingRuDirect

  CoreSettings copyWith({
    bool? manageTun,
    String? tunStack,
    bool? strictRoute,
    int? mtu,
    List<String>? routeExclude,
    List<String>? proxyBypass,
    int? mixedPort,
    bool? allowLan,
    String? ipv6,
    String? logLevel,
    bool? findProcess,
    bool? dnsOverride,
    List<String>? dnsRemote,
    List<String>? dnsDirect,
    String? linkRouting,
  }) =>
      CoreSettings(
        manageTun: manageTun ?? this.manageTun,
        tunStack: tunStack ?? this.tunStack,
        strictRoute: strictRoute ?? this.strictRoute,
        mtu: mtu ?? this.mtu,
        routeExclude: routeExclude ?? this.routeExclude,
        proxyBypass: proxyBypass ?? this.proxyBypass,
        mixedPort: mixedPort ?? this.mixedPort,
        allowLan: allowLan ?? this.allowLan,
        ipv6: ipv6 ?? this.ipv6,
        logLevel: logLevel ?? this.logLevel,
        findProcess: findProcess ?? this.findProcess,
        dnsOverride: dnsOverride ?? this.dnsOverride,
        dnsRemote: dnsRemote ?? this.dnsRemote,
        dnsDirect: dnsDirect ?? this.dnsDirect,
        linkRouting: linkRouting ?? this.linkRouting,
      );

  /// What the core gets as "tuning".
  Map<String, dynamic> tuning() => {
        if (manageTun) ...{
          'strictRoute': strictRoute,
          'mtu': mtu,
          'routeExclude': routeExclude,
        },
        if (ipv6 != 'profile') 'ipv6': ipv6 == 'on',
        if (logLevel.isNotEmpty) 'logLevel': logLevel,
        if (allowLan) 'allowLan': true,
        if (dnsOverride && dnsRemote.isNotEmpty && dnsDirect.isNotEmpty)
          'dns': {'remote': dnsRemote, 'direct': dnsDirect},
      };

  Map<String, dynamic> toJson() => {
        'manageTun': manageTun,
        'tunStack': tunStack,
        'strictRoute': strictRoute,
        'mtu': mtu,
        'routeExclude': routeExclude,
        'proxyBypass': proxyBypass,
        'mixedPort': mixedPort,
        'allowLan': allowLan,
        'ipv6': ipv6,
        'logLevel': logLevel,
        'findProcess': findProcess,
        'dnsOverride': dnsOverride,
        'dnsRemote': dnsRemote,
        'dnsDirect': dnsDirect,
        'linkRouting': linkRouting,
      };

  static CoreSettings fromJson(Object? v) {
    if (v is! Map) return const CoreSettings();
    List<String>? list(Object? x) => x is List ? x.map((e) => e.toString()).toList() : null;
    const d = CoreSettings();
    final stack = v['tunStack'];
    final ip6 = v['ipv6'];
    final log = v['logLevel'];
    return CoreSettings(
      manageTun: v['manageTun'] as bool? ?? d.manageTun,
      tunStack: const ['gvisor', 'mixed', 'system'].contains(stack) ? stack as String : d.tunStack,
      strictRoute: v['strictRoute'] as bool? ?? d.strictRoute,
      mtu: (v['mtu'] as num?)?.toInt() ?? d.mtu,
      routeExclude: list(v['routeExclude']) ?? d.routeExclude,
      proxyBypass: list(v['proxyBypass']) ?? d.proxyBypass,
      mixedPort: (v['mixedPort'] as num?)?.toInt() ?? d.mixedPort,
      allowLan: v['allowLan'] as bool? ?? d.allowLan,
      ipv6: const ['profile', 'on', 'off'].contains(ip6) ? ip6 as String : d.ipv6,
      logLevel: const ['', 'debug', 'info', 'warning', 'error', 'silent'].contains(log) ? log as String : d.logLevel,
      findProcess: v['findProcess'] as bool? ?? d.findProcess,
      dnsOverride: v['dnsOverride'] as bool? ?? d.dnsOverride,
      dnsRemote: list(v['dnsRemote']) ?? d.dnsRemote,
      dnsDirect: list(v['dnsDirect']) ?? d.dnsDirect,
      linkRouting: const [routingAll, routingRuDirect].contains(v['linkRouting']) ? v['linkRouting'] as String : d.linkRouting,
    );
  }
}

/// UI preferences, stored as ui.json in [appDataDir].
class Settings extends ChangeNotifier {
  Settings({
    this.themeMode = ThemeMode.system,
    this.languageCode,
    this.corePref = CorePref.auto,
    this.proxyMode = ProxyMode.systemProxy,
    this.closeToTray = true,
    this.launchAtStartup = false,
    this.startMinimized = false,
    this.autoConnect = false,
    this.checkUpdates = true,
    this.vpnNotification = true,
    this.uiMode,
    this.welcomeDone = false,
    this.showExitInfo = true,
    this.file,
  });

  ThemeMode themeMode;
  String? languageCode; // null: follow the system
  CorePref corePref;
  ProxyMode proxyMode;
  bool closeToTray; // closing the window hides it to the tray
  bool launchAtStartup; // mirrors the OS autostart entry
  bool startMinimized; // start hidden in the tray
  bool autoConnect; // connect right after start
  bool checkUpdates; // look for a new release on start
  bool vpnNotification; // Android: a normal "VPN is running" notification (false: folded)
  UiMode? uiMode; // null: not chosen yet, ask on start
  bool welcomeDone; // first start finished (mode chosen, panel sign-in offered)
  bool showExitInfo; // look up the exit IP and country after connecting

  bool get simple => uiMode == UiMode.simple;
  /// Global hotkey that toggles the VPN, as hotkey_manager JSON; null = none.
  Map<String, dynamic>? toggleHotkey;
  CoreSettings core = const CoreSettings();

  /// Bumped on every change of [core]; AppState compares it with the value it
  /// connected with to offer "apply" (a reconnect).
  int coreRevision = 0;
  final File? file;

  Locale? get locale => languageCode == null ? null : Locale(languageCode!);

  static File? defaultFile() {
    final d = appDataDir();
    return d == null ? null : File('${d.path}${Platform.pathSeparator}ui.json');
  }

  static Future<Settings> load([File? file]) async {
    file ??= defaultFile();
    final s = Settings(file: file);
    try {
      if (file != null && await file.exists()) {
        final m = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        s.themeMode = ThemeMode.values.asNameMap()[m['theme']] ?? ThemeMode.system;
        final lang = m['language'];
        s.languageCode = (lang == 'ru' || lang == 'en') ? lang as String : null;
        s.corePref = CorePref.values.asNameMap()[m['core']] ?? CorePref.auto;
        s.proxyMode = ProxyMode.values.asNameMap()[m['mode']] ?? ProxyMode.systemProxy;
        s.closeToTray = m['closeToTray'] as bool? ?? true;
        s.launchAtStartup = m['launchAtStartup'] as bool? ?? false;
        s.startMinimized = m['startMinimized'] as bool? ?? false;
        s.autoConnect = m['autoConnect'] as bool? ?? false;
        s.checkUpdates = m['checkUpdates'] as bool? ?? true;
        s.vpnNotification = m['vpnNotification'] as bool? ?? true;
        s.uiMode = UiMode.values.asNameMap()[m['uiMode']];
        s.welcomeDone = m['welcomeDone'] as bool? ?? false;
        s.showExitInfo = m['showExitInfo'] as bool? ?? true;
        s.core = CoreSettings.fromJson(m['coreSettings']);
        final hk = m['toggleHotkey'];
        s.toggleHotkey = hk is Map ? hk.cast<String, dynamic>() : null;
      }
    } catch (_) {
      // Broken or unreadable file: start with defaults.
    }
    return s;
  }

  Future<void> _save() async {
    final f = file;
    if (f == null) return;
    try {
      await f.parent.create(recursive: true);
      await f.writeAsString(jsonEncode({
        'theme': themeMode.name,
        'language': languageCode,
        'core': corePref.name,
        'mode': proxyMode.name,
        'closeToTray': closeToTray,
        'launchAtStartup': launchAtStartup,
        'startMinimized': startMinimized,
        'autoConnect': autoConnect,
        'checkUpdates': checkUpdates,
        'vpnNotification': vpnNotification,
        'uiMode': uiMode?.name,
        'welcomeDone': welcomeDone,
        'showExitInfo': showExitInfo,
        'coreSettings': core.toJson(),
        'toggleHotkey': toggleHotkey,
      }));
    } catch (_) {
      // Not fatal: the choice still applies for this session.
    }
  }

  void setThemeMode(ThemeMode v) {
    themeMode = v;
    notifyListeners();
    _save();
  }

  void setLanguage(String? v) {
    languageCode = v;
    notifyListeners();
    _save();
  }

  void setCorePref(CorePref v) {
    corePref = v;
    notifyListeners();
    _save();
  }

  void setProxyMode(ProxyMode v) {
    proxyMode = v;
    notifyListeners();
    _save();
  }

  void setCloseToTray(bool v) {
    closeToTray = v;
    notifyListeners();
    _save();
  }

  void setLaunchAtStartup(bool v) {
    launchAtStartup = v;
    notifyListeners();
    _save();
  }

  void setStartMinimized(bool v) {
    startMinimized = v;
    notifyListeners();
    _save();
  }

  void setAutoConnect(bool v) {
    autoConnect = v;
    notifyListeners();
    _save();
  }

  void setCore(CoreSettings v) {
    core = v;
    coreRevision++;
    notifyListeners();
    _save();
  }

  void setToggleHotkey(Map<String, dynamic>? v) {
    toggleHotkey = v;
    notifyListeners();
    _save();
  }

  void setCheckUpdates(bool v) {
    checkUpdates = v;
    notifyListeners();
    _save();
  }

  void setWelcomeDone() {
    welcomeDone = true;
    notifyListeners();
    _save();
  }

  void setUiMode(UiMode v) {
    uiMode = v;
    notifyListeners();
    _save();
  }

  void setShowExitInfo(bool v) {
    showExitInfo = v;
    notifyListeners();
    _save();
  }

  void setVpnNotification(bool v) {
    vpnNotification = v;
    notifyListeners();
    _save();
  }
}
