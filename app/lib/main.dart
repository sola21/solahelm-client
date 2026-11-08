import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/backend.dart';
import 'core/daemon_backend.dart';
import 'core/fake_backend.dart';
import 'desktop.dart';
import 'l10n/app_localizations.dart';
import 'shell.dart';
import 'state/app_state.dart';
import 'state/scope.dart';
import 'state/settings.dart';
import 'state/sub_store.dart';
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
  if (exe != null && dataDir != null) {
    backend = DaemonBackend(executable: exe, workDir: '${dataDir.path}${Platform.pathSeparator}core');
    store = FileSubStore(dataDir);
  } else {
    backend = FakeBackend();
    store = MemorySubStore();
  }
  final state = AppState(settings, backend, store, isDemo: exe == null);
  await state.init();

  DesktopShell? desktop;
  if (DesktopShell.supported) {
    desktop = DesktopShell(state);
    // Autostart passes --minimized; "start minimized" also applies to manual starts.
    final hidden = args.contains(DesktopShell.minimizedFlag) || settings.startMinimized;
    await desktop.init(startHidden: hidden);
  }
  runApp(SolaHelmApp(state: state, desktop: desktop));

  if (settings.autoConnect && state.subscription != null) {
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
