import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solahelm_client/core/fake_backend.dart';
import 'package:solahelm_client/main.dart';
import 'package:solahelm_client/models.dart';
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
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final b = await Settings.load(file);
    expect(b.themeMode, ThemeMode.dark);
    expect(b.languageCode, 'en');
    expect(b.corePref, CorePref.mihomo);
    expect(b.proxyMode, ProxyMode.systemProxy);

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
