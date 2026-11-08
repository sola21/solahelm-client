import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solahelm_client/core/backend.dart';
import 'package:solahelm_client/core/fake_backend.dart';
import 'package:solahelm_client/main.dart';
import 'package:solahelm_client/models.dart';
import 'package:solahelm_client/screens/home.dart';
import 'package:solahelm_client/state/app_state.dart';
import 'package:solahelm_client/state/settings.dart';
import 'package:solahelm_client/state/sub_store.dart';

AppState newState({String? lang = 'ru', ProxyMode mode = ProxyMode.portOnly}) => AppState(
      Settings(languageCode: lang, themeMode: ThemeMode.light, proxyMode: mode),
      FakeBackend(random: Random(1), startDelay: const Duration(milliseconds: 50)),
      MemorySubStore(),
    );

Future<void> pumpApp(WidgetTester t, AppState st, Size size) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await st.init();
  await t.pumpWidget(SolaHelmApp(state: st));
  await t.pumpAndSettle();
}

/// Connected state starts periodic timers; stop them before the test ends.
Future<void> finish(WidgetTester t, AppState st) async {
  await t.runAsync(st.disconnect);
  await t.pumpAndSettle();
}

Future<void> addSub(WidgetTester t, String url) async {
  await t.tap(find.byTooltip(find.text('Подписки').evaluate().isNotEmpty ? 'Добавить подписку' : 'Add subscription'));
  await t.pumpAndSettle();
  await t.enterText(find.byType(TextField), url);
  await t.tap(find.byType(FilledButton).last);
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
  await t.pumpAndSettle();
  // The "added" snackbar would cover buttons at the bottom of the next screens.
  t.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger)).clearSnackBars();
  await t.pumpAndSettle();
}

void main() {
  testWidgets('connect without a subscription sends you to add one', (t) async {
    final st = newState();
    await pumpApp(t, st, const Size(390, 844));
    expect(find.text('Отключено'), findsOneWidget);

    await t.tap(find.byIcon(Icons.power_settings_new));
    await t.pumpAndSettle();
    expect(find.text('Сначала добавьте подписку'), findsOneWidget);
    expect(find.text('Пока нет подписок'), findsOneWidget);
    expect(st.status, LinkStatus.disconnected);
  });

  testWidgets('add subscription validates the link, then connect and pick a node', (t) async {
    final st = newState(lang: 'en');
    await pumpApp(t, st, const Size(390, 844));
    await t.tap(find.text('Subscriptions'));
    await t.pumpAndSettle();

    await t.tap(find.byTooltip('Add subscription'));
    await t.pumpAndSettle();
    await t.tap(find.byType(FilledButton).last);
    await t.pump();
    expect(find.text('Enter a link'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'panel.example.org/sub');
    await t.tap(find.byType(FilledButton).last);
    await t.pump();
    expect(find.text('The link must start with http:// or https://'), findsOneWidget);

    await t.enterText(find.byType(TextField), 'https://panel.example.org/sub/abc/clash');
    await t.tap(find.byType(FilledButton).last);
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await t.pumpAndSettle();
    expect(st.subscriptions.single.core, CoreKind.mihomo);
    expect(find.text('panel.example.org'), findsOneWidget);
    expect(find.text('mihomo'), findsOneWidget);

    await t.tap(find.text('Home'));
    await t.pumpAndSettle();
    await t.runAsync(st.connect);
    await t.pumpAndSettle();
    expect(st.status, LinkStatus.connected);
    expect(find.text('Connected'), findsOneWidget);

    await t.tap(find.text('Nodes'));
    await t.pumpAndSettle();
    expect(find.text('auto'), findsWidgets);
    await t.tap(find.text('FL-Finland-AnyTLS'));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await t.pumpAndSettle();
    expect(st.group!.now, 'FL-Finland-AnyTLS');
    expect(st.node!.name, 'FL-Finland-AnyTLS');

    await t.tap(find.text('Ping'));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await t.pumpAndSettle();
    expect(st.leaves['DE-Germany-Hysteria2']!.delayMs, isNotNull);
    expect(st.leaves['US-Lite-Trojan']!.timedOut, isTrue);

    await finish(t, st);
  });

  testWidgets('TUN without admin rights elevates right away, no dialog', (t) async {
    final st = newState(mode: ProxyMode.tun);
    await pumpApp(t, st, const Size(1200, 800));
    await t.tap(find.text('Подписки'));
    await t.pumpAndSettle();
    await addSub(t, 'https://panel.example.org/sub/abc/singbox');

    await t.tap(find.text('Главная'));
    await t.pumpAndSettle();
    await t.tap(find.text('Подключить'));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await t.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(st.status, LinkStatus.connected);
    expect(st.backend.elevated, isTrue);
    expect(find.textContaining('администратор'), findsWidgets);

    await finish(t, st);
  });

  testWidgets('declined elevation shows a not-enough-rights error', (t) async {
    final st = newState(mode: ProxyMode.tun);
    (st.backend as FakeBackend).denyElevation = true;
    await pumpApp(t, st, const Size(1200, 800));
    await t.tap(find.text('Подписки'));
    await t.pumpAndSettle();
    await addSub(t, 'https://panel.example.org/sub/abc/singbox');
    await t.tap(find.text('Главная'));
    await t.pumpAndSettle();
    await t.tap(find.text('Подключить'));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await t.pumpAndSettle();
    expect(st.status, LinkStatus.disconnected);
    expect(find.textContaining('Недостаточно прав для TUN'), findsOneWidget);
  });

  testWidgets('connections grouped by process, details, close; logs', (t) async {
    final st = newState(lang: 'en');
    await pumpApp(t, st, const Size(1300, 900));
    await t.tap(find.text('Subscriptions'));
    await t.pumpAndSettle();
    await addSub(t, 'https://panel.example.org/sub/abc/clash');
    await t.runAsync(st.connect);
    await t.runAsync(st.refreshTraffic);
    await t.pumpAndSettle();

    await t.tap(find.text('Connections').first);
    await t.pumpAndSettle();
    expect(find.text('opera.exe'), findsOneWidget);
    expect(find.text('Telegram.exe'), findsOneWidget);
    expect(find.text('Processes: 2'), findsOneWidget);

    await t.tap(find.text('opera.exe'));
    await t.pumpAndSettle();
    expect(find.text('youtube.com:443'), findsOneWidget);
    expect(find.text('ya.ru:443'), findsOneWidget);

    await t.tap(find.text('youtube.com:443'));
    await t.pumpAndSettle();
    expect(find.text('opera.exe → youtube.com'), findsOneWidget);
    expect(find.text('proxy → DE-Germany-Hysteria2'), findsOneWidget);
    await t.tap(find.widgetWithText(FilledButton, 'Close'));
    await t.pumpAndSettle();

    await t.runAsync(() => st.closeConnection('c1'));
    await t.pumpAndSettle();
    expect(st.connections.any((c) => c.id == 'c1'), isFalse);
    expect(st.closedConnections.any((c) => c.id == 'c1'), isTrue);

    await t.tap(find.text('Logs'));
    await t.pumpAndSettle();
    expect(find.textContaining('api.ipify.org'), findsWidgets);

    await finish(t, st);
  });

  testWidgets('paste config text from the clipboard creates a profile', (t) async {
    final st = newState(lang: 'en');
    await pumpApp(t, st, const Size(1200, 900));
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') return {'text': 'proxies: []\nrules:\n  - MATCH,DIRECT\n'};
      return null;
    });
    addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await t.tap(find.text('Subscriptions').first);
    await t.pumpAndSettle();
    await t.tap(find.text('Paste'));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await t.pumpAndSettle();
    expect(st.subscriptions.single.source, SubSource.pasted);
    expect(st.subscriptions.single.core, CoreKind.mihomo);
    expect(find.text('pasted'), findsOneWidget);
  });

  test('import a config file', () async {
    final dir = await Directory.systemTemp.createTemp('solahelm-import-');
    addTearDown(() => dir.delete(recursive: true));
    final f = File('${dir.path}${Platform.pathSeparator}my.json')..writeAsStringSync('{"outbounds":[]}');
    final st = newState();
    await st.init();
    expect(await st.importFile(f.path), isNull);
    expect(st.subscriptions.single.name, 'my.json');
    expect(st.subscriptions.single.source, SubSource.file);
    expect(st.subscriptions.single.core, CoreKind.singBox);
    f.writeAsStringSync('broken');
    expect(await st.importFile(f.path), isNotNull);
  });

  testWidgets('profile editor checks and saves edits', (t) async {
    final st = newState(lang: 'en');
    await pumpApp(t, st, const Size(1200, 900));
    await t.tap(find.text('Subscriptions').first);
    await t.pumpAndSettle();
    await addSub(t, 'https://panel.example.org/sub/abc/clash');
    final id = st.subscriptions.single.id;

    await t.tap(find.byIcon(Icons.more_vert));
    await t.pumpAndSettle();
    await t.tap(find.text('Open and edit'));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await t.pumpAndSettle();
    expect(find.text('proxies: []'), findsOneWidget);

    await t.enterText(find.byType(TextField), 'broken config');
    await t.tap(find.text('Check'));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await t.pumpAndSettle();
    expect(find.textContaining('Error:'), findsOneWidget);

    await t.enterText(find.byType(TextField), 'proxies: []\nrules: []\n');
    await t.tap(find.text('Save'));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await t.pumpAndSettle();
    expect(await st.profileContent(id), 'proxies: []\nrules: []\n');
    expect(st.subscriptions.single.edited, isTrue);
  });

  testWidgets('rules editor: add to top, delete, save; rules reach the core', (t) async {
    final st = newState(lang: 'en');
    await pumpApp(t, st, const Size(1300, 900));
    await t.tap(find.text('Subscriptions').first);
    await t.pumpAndSettle();
    await addSub(t, 'https://panel.example.org/sub/abc/clash');

    await t.tap(find.text('Rules').first);
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await t.pumpAndSettle();
    expect(find.text('ya.ru'), findsOneWidget); // profile rules shown while disconnected

    await t.tap(find.text('Edit'));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await t.pumpAndSettle();
    expect(find.text('Rules: panel.example.org'), findsOneWidget);

    await t.enterText(find.widgetWithText(TextField, 'Value'), 'telegram.org');
    await t.tap(find.text('To top'));
    await t.pumpAndSettle();
    // delete GEOIP,RU
    final geo = find.ancestor(of: find.text('RU'), matching: find.byType(Card));
    await t.tap(find.descendant(of: geo, matching: find.byIcon(Icons.delete_outline)));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Save'));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await t.pumpAndSettle();

    final sub = st.subscriptions.single;
    expect(sub.rules, ['DOMAIN-SUFFIX,telegram.org,DIRECT', 'DOMAIN-SUFFIX,ya.ru,DIRECT', 'MATCH,proxy']);
    expect(sub.rulesReplace, isTrue);

    await t.runAsync(st.connect);
    await t.pumpAndSettle();
    expect((st.backend as FakeBackend).lastRules, sub.rules);
    await finish(t, st);
  });

  testWidgets('rules editor text mode reports a bad line', (t) async {
    final st = newState(lang: 'en');
    await pumpApp(t, st, const Size(1300, 900));
    await t.tap(find.text('Subscriptions').first);
    await t.pumpAndSettle();
    await addSub(t, 'https://panel.example.org/sub/abc/clash');
    await t.tap(find.text('Rules').first);
    await t.pumpAndSettle();
    await t.tap(find.text('Edit'));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await t.pumpAndSettle();
    await t.tap(find.text('As text'));
    await t.pumpAndSettle();
    final editor = find.byWidgetPredicate((w) => w is TextField && w.expands);
    await t.enterText(editor, '- DOMAIN,a.com,DIRECT\n- nonsense\n');
    await t.tap(find.widgetWithText(FilledButton, 'Save'));
    await t.pumpAndSettle();
    expect(find.textContaining('Bad rule on line 2'), findsOneWidget);
    expect(st.subscriptions.single.rules, isNull);
  });

  testWidgets('disconnect does not hang on a silent log stream; button is disabled meanwhile', (t) async {
    final st = newState(lang: 'en');
    final fake = st.backend as FakeBackend
      ..hangLogs = true
      ..stopDelay = const Duration(milliseconds: 300);
    await pumpApp(t, st, const Size(390, 844));
    await t.tap(find.text('Subscriptions'));
    await t.pumpAndSettle();
    await addSub(t, 'https://panel.example.org/sub/abc/clash');
    await t.tap(find.text('Home'));
    await t.pumpAndSettle();
    await t.runAsync(st.connect);
    await t.pumpAndSettle();
    expect(st.status, LinkStatus.connected);

    final done = st.disconnect();
    await t.pump();
    expect(st.status, LinkStatus.disconnecting);
    expect(find.text('Disconnecting…'), findsOneWidget);
    final ink = t.widget<InkWell>(find.descendant(of: find.byType(PowerButton), matching: find.byType(InkWell)));
    expect(ink.onTap, isNull); // greyed out, can't be pressed twice
    await t.tap(find.byType(PowerButton), warnIfMissed: false);
    var finished = false;
    unawaited(done.then((_) => finished = true));
    // The old code awaited the log stream's cancel, which never completes here.
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle();
    expect(finished, isTrue);
    expect(st.status, LinkStatus.disconnected);
    expect(fake.lastRules, isNull);
  });

  testWidgets('connection settings reach the core; changes while connected offer a reconnect', (t) async {
    final st = newState(lang: 'en');
    final fake = st.backend as FakeBackend;
    await pumpApp(t, st, const Size(1200, 1000));
    await t.tap(find.text('Subscriptions').first);
    await t.pumpAndSettle();
    await addSub(t, 'https://panel.example.org/sub/abc/clash');

    await t.tap(find.text('Settings').first);
    await t.pumpAndSettle();
    await t.tap(find.text('Connection and TUN').last);
    await t.pumpAndSettle();
    await t.tap(find.text('Manage TUN settings'));
    await t.pumpAndSettle();
    expect(st.settings.core.manageTun, isTrue);

    final field = find.widgetWithText(TextField, '192.168.1.0/24');
    await t.enterText(field, '10.1.2.3');
    await t.tap(find.text('Add network'));
    await t.pumpAndSettle();
    expect(find.text('Expected a network like 192.168.1.0/24'), findsOneWidget);
    await t.enterText(field, '10.77.0.0/16');
    await t.tap(find.text('Add network'));
    await t.pumpAndSettle();
    expect(st.settings.core.routeExclude, contains('10.77.0.0/16'));

    await t.runAsync(st.connect);
    await t.pumpAndSettle();
    expect(fake.lastTuning?['routeExclude'], contains('10.77.0.0/16'));
    expect(fake.lastTuning?['strictRoute'], isTrue);
    expect(st.needsReapply, isFalse);

    await t.ensureVisible(find.text('Allow connections from the LAN'));
    await t.pumpAndSettle();
    await t.tap(find.text('Allow connections from the LAN'));
    await t.pumpAndSettle();
    expect(st.needsReapply, isTrue);
    expect(find.text('Reconnect'), findsOneWidget);
    await t.tap(find.text('Reconnect'));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await t.pumpAndSettle();
    expect(fake.lastTuning?['allowLan'], isTrue);
    expect(st.needsReapply, isFalse);
    expect(find.text('Reconnect'), findsNothing);
    await finish(t, st);
  });

  testWidgets('a core left running is taken over on start', (t) async {
    final st = newState(lang: 'en');
    (st.backend as FakeBackend).leftRunning =
        CoreStatus(running: true, core: CoreKind.mihomo, mode: ProxyMode.portOnly, port: 7890, startedAt: DateTime.now());
    await st.init();
    await t.runAsync(st.attachRunningCore);
    await t.pumpWidget(SolaHelmApp(state: st));
    await t.pumpAndSettle();
    expect(st.status, LinkStatus.connected);
    expect(find.text('Disconnect'), findsOneWidget);
    await t.runAsync(st.detachForExit);
    expect((st.backend as FakeBackend).detached, isTrue);
    await finish(t, st);
  });

  testWidgets('settings switch language, theme and core', (t) async {
    final st = newState();
    await pumpApp(t, st, const Size(1200, 900));
    await t.tap(find.text('Настройки'));
    await t.pumpAndSettle();

    await t.tap(find.text('English'));
    await t.pumpAndSettle();
    expect(find.text('Theme'), findsOneWidget);

    await t.tap(find.text('Dark'));
    await t.pumpAndSettle();
    expect(Theme.of(t.element(find.text('Theme'))).brightness, Brightness.dark);

    await t.tap(find.descendant(of: find.byType(SegmentedButton<CorePref>), matching: find.text('sing-box')));
    await t.pumpAndSettle();
    expect(st.core, CoreKind.singBox);
    expect(st.coreIsAuto, isFalse);
  });

  test('settings round-trip through the JSON file', () async {
    final dir = await Directory.systemTemp.createTemp('solahelm-settings-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/ui.json');

    final a = await Settings.load(file);
    expect(a.themeMode, ThemeMode.system);
    a.setThemeMode(ThemeMode.dark);
    a.setLanguage('en');
    a.setCorePref(CorePref.mihomo);
    a.setProxyMode(ProxyMode.systemProxy);
    a.setCore(a.core.copyWith(manageTun: true, tunStack: 'system', mtu: 1400, routeExclude: ['10.9.0.0/16'], ipv6: 'off'));
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final b = await Settings.load(file);
    expect(b.themeMode, ThemeMode.dark);
    expect(b.languageCode, 'en');
    expect(b.corePref, CorePref.mihomo);
    expect(b.proxyMode, ProxyMode.systemProxy);
    expect(b.core.manageTun, isTrue);
    expect(b.core.tunStack, 'system');
    expect(b.core.mtu, 1400);
    expect(b.core.routeExclude, ['10.9.0.0/16']);
    expect(b.core.tuning(), {'strictRoute': true, 'mtu': 1400, 'routeExclude': ['10.9.0.0/16'], 'ipv6': false});

    await file.writeAsString('{broken');
    final c = await Settings.load(file);
    expect(c.themeMode, ThemeMode.system);
  });

  test('subscriptions survive a restart', () async {
    final dir = await Directory.systemTemp.createTemp('solahelm-subs-');
    addTearDown(() => dir.delete(recursive: true));
    final store = FileSubStore(dir);
    final sub = Subscription(
      id: 'a1',
      name: 'Моя панель',
      url: 'https://x/sub/t/clash',
      format: SubFormat.clashYaml,
      core: CoreKind.mihomo,
      download: 5 << 30,
      total: 100 << 30,
      expire: DateTime(2027, 2, 1),
    );
    await store.save([sub], 'a1');
    await store.saveContent('a1', 'proxies: []');

    final (list, active) = await FileSubStore(dir).load();
    expect(active, 'a1');
    expect(list.single.name, 'Моя панель');
    expect(list.single.core, CoreKind.mihomo);
    expect(list.single.usedGb, 5);
    expect(list.single.totalGb, 100);
    expect(list.single.expire, DateTime(2027, 2, 1));
    expect(await FileSubStore(dir).content('a1'), 'proxies: []');
  });
}
