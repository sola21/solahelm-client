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
}
