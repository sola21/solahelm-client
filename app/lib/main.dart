import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/android_backend.dart';
import 'core/backend.dart';
import 'core/daemon_backend.dart';
import 'core/fake_backend.dart';
import 'core/updater.dart';
import 'desktop.dart';
import 'l10n/app_localizations.dart';
import 'models.dart';
import 'shell.dart';
import 'state/app_state.dart';
import 'state/scope.dart';
import 'state/settings.dart';
import 'state/sub_store.dart';
import 'screens/settings.dart' show appVersion;
import 'theme.dart';

/// `flutter run --dart-define=DEMO=true` runs on fake data without a core.
const demo = bool.fromEnvironment('DEMO');

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await Settings.load();
  final dataDir = appDataDir();
  final exe = demo ? null : DaemonBackend.locate();

  final CoreBackend backend;
  final SubStore store;
  if (Platform.isAndroid && dataDir != null && !demo) {
    backend = AndroidBridge.backend('${dataDir.path}/core');
    store = FileSubStore(dataDir);
  } else if (exe != null && dataDir != null) {
    backend = DaemonBackend(executable: exe, workDir: '${dataDir.path}${Platform.pathSeparator}core');
    store = FileSubStore(dataDir);
  } else {
    backend = FakeBackend();
    store = MemorySubStore();
  }
  final state = AppState(settings, backend, store, isDemo: exe == null && !(Platform.isAndroid && !demo));
  AndroidBridge.onRevoked = () => state.disconnect();
  AndroidBridge.onCoreChanged = () => state.syncWithCore();
  if (Platform.isAndroid && !demo) {
    var notify = settings.vpnNotification;
    unawaited(AndroidBridge.setNotificationVisible(notify).catchError((_) {}));
    settings.addListener(() {
      if (settings.vpnNotification == notify) return;
      notify = settings.vpnNotification;
      unawaited(AndroidBridge.setNotificationVisible(notify).catchError((_) {}));
    });
  }
  if (Platform.isWindows && exe != null) {
    state.updater = Updater(currentVersion: appVersion, portable: isPortable);
  }
  await state.init();
  await state.attachRunningCore(); // after "exit, keep the core"

  DesktopShell? desktop;
  if (DesktopShell.supported) {
    desktop = DesktopShell(state);
    // Autostart passes --minimized; "start minimized" also applies to manual starts.
    final hidden = args.contains(DesktopShell.minimizedFlag) || settings.startMinimized;
    await desktop.init(startHidden: hidden);
  }
  runApp(SolaHelmApp(state: state, desktop: desktop));
  if (settings.checkUpdates && state.updater != null) {
    // Give the window (and a possible auto-connect) a moment first.
    Future<void>.delayed(const Duration(seconds: 8), () => state.checkForUpdates(silent: true));
  }

  final connectNow = args.contains(DesktopShell.connectFlag) || settings.autoConnect;
  if (connectNow && state.subscription != null && state.status == LinkStatus.disconnected) {
    await state.connect(); // TUN: goes straight to the UAC prompt if needed
  }
}

class SolaHelmApp extends StatelessWidget {
  const SolaHelmApp({super.key, required this.state, this.desktop});
  final AppState state;
  final DesktopShell? desktop;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state.settings,
      builder: (context, _) => MaterialApp(
        title: 'SolaHelm',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: state.settings.themeMode,
        locale: state.settings.locale,
        supportedLocales: S.supportedLocales,
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // Anything that isn't Russian falls back to English.
        localeResolutionCallback: (device, supported) =>
            device?.languageCode == 'ru' ? const Locale('ru') : const Locale('en'),
        home: AppScope(state: state, child: const Shell()),
      ),
    );
  }
}
