import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solahelm_client/core/fake_backend.dart';
import 'package:solahelm_client/core/panel_api.dart';
import 'package:solahelm_client/main.dart';
import 'package:solahelm_client/models.dart';
import 'package:solahelm_client/state/app_state.dart';
import 'package:solahelm_client/state/settings.dart';
import 'package:solahelm_client/state/sub_store.dart';

/// The panel's app API, without a network.
class FakePanelApi extends PanelApi {
  FakePanelApi();
  String password = 'secret';
  List<PanelProfile> list = const [
    PanelProfile(id: 1, name: 'alpha', state: 'on', subscriptionUrl: 'https://panel.example.org/hy/sub/tokA'),
    PanelProfile(id: 2, name: 'beta', state: 'expired'),
  ];
  bool revoked = false;
  final calls = <String>[];

  PanelReply _reply(String? token) => PanelReply(
      panelName: 'SolaHelm', panelVersion: '1.15.0', clientLogin: 'test1', clientName: 'Test One',
      profiles: list, token: token);

  @override
  Future<PanelReply> login(String url, String login, String password, {bool selfSigned = false}) async {
    calls.add('login $url $login${selfSigned ? ' self-signed' : ''}');
    if (password != this.password) throw PanelException('bad_credentials');
    revoked = false;
    return _reply('sht_token');
  }

  @override
  Future<PanelReply> profiles(String url, String token, {bool selfSigned = false}) async {
    calls.add('profiles $token');
    if (revoked) throw PanelException('unauthorized');
    return _reply(null);
  }

  @override
  Future<void> logout(String url, String token, {bool selfSigned = false}) async => calls.add('logout $token');
}

Future<(AppState, FakePanelApi)> pumpSubs(WidgetTester t) async {
  final st = AppState(
    Settings(languageCode: 'ru', themeMode: ThemeMode.light, proxyMode: ProxyMode.portOnly, uiMode: UiMode.advanced, welcomeDone: true),
    FakeBackend(random: Random(1), startDelay: const Duration(milliseconds: 50)),
    MemorySubStore(),
  );
  final api = FakePanelApi();
  st.panelApi = api;
  t.view.physicalSize = const Size(1200, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await st.init();
  await t.pumpWidget(SolaHelmApp(state: st));
  await t.pumpAndSettle();
  await t.tap(find.text('Подписки'));
  await t.pumpAndSettle();
  return (st, api);
}

Future<void> signIn(WidgetTester t, String password, {bool selfSigned = false}) async {
  final fields = find.byType(TextField);
  await t.enterText(fields.at(0), 'panel.example.org/hy/');
  await t.enterText(fields.at(1), 'test1');
  if (selfSigned) await t.tap(find.text('У панели самоподписанный сертификат'));
  await t.enterText(fields.at(2), password);
  await t.tap(find.widgetWithText(FilledButton, 'Войти в панель').last); // the dialog's button
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
  await t.pumpAndSettle();
}

void main() {
  test('panel address is normalised; plain http only for this computer', () {
    expect(PanelApi.normalizeUrl('panel.example.org/hy/'), 'https://panel.example.org/hy');
    expect(PanelApi.normalizeUrl(' https://panel.example.org/hy/login '), 'https://panel.example.org/hy');
    expect(PanelApi.normalizeUrl('https://panel.example.org:8443/x/api/app/login'), 'https://panel.example.org:8443/x');
    expect(PanelApi.normalizeUrl('http://127.0.0.1:8088/hy'), 'http://127.0.0.1:8088/hy');
    expect(() => PanelApi.normalizeUrl('http://panel.example.org/hy'), throwsA(isA<PanelException>().having((e) => e.code, 'code', 'insecure')));
    expect(() => PanelApi.normalizeUrl(''), throwsA(isA<PanelException>()));
  });

  testWidgets('sign in: active profiles become subscriptions, inactive ones are shown', (t) async {
    final (st, api) = await pumpSubs(t);
    await t.tap(find.text('Войти в панель SolaHelm'));
    await t.pumpAndSettle();
    // No panel address is filled in: only an example as a hint.
    expect(find.text('https://panel.example.org/hy/'), findsOneWidget);
    expect(st.panels, isEmpty);

    await signIn(t, 'wrong');
    expect(find.text('Неверный логин или пароль'), findsOneWidget);
    expect(st.panels, isEmpty);

    await signIn(t, 'secret');
    expect(api.calls.last, 'login https://panel.example.org/hy test1');
    expect(st.panels.single.token, 'sht_token');
    expect(st.subscriptions, hasLength(1));
    expect(st.subscriptions.single.panelId, st.panels.single.id);
    expect(st.subscriptions.single.url, 'https://panel.example.org/hy/sub/tokA');
    expect(find.text('SolaHelm · Test One'), findsOneWidget);
    expect(find.text('beta: срок истёк'), findsOneWidget);
    expect(find.text('панель'), findsOneWidget); // badge on the subscription card
  });

  testWidgets('sync adds new profiles, follows a re-issued link; a revoked token asks to sign in again', (t) async {
    final (st, api) = await pumpSubs(t);
    await t.tap(find.text('Войти в панель SolaHelm'));
    await t.pumpAndSettle();
    await signIn(t, 'secret');
    final firstId = st.subscriptions.single.id;

    api.list = const [
      PanelProfile(id: 1, name: 'alpha', state: 'on', subscriptionUrl: 'https://panel.example.org/hy/sub/tokA2'),
      PanelProfile(id: 3, name: 'gamma', state: 'on', subscriptionUrl: 'https://panel.example.org/hy/sub/tokC'),
    ];
    await t.runAsync(() => st.syncPanel(st.panels.single.id));
    await t.pumpAndSettle();
    expect(st.subscriptions, hasLength(2));
    expect(st.subscriptions.firstWhere((x) => x.id == firstId).url, endsWith('tokA2'));

    api.revoked = true;
    expect(await t.runAsync(() => st.syncPanel(st.panels.single.id)), 'unauthorized');
    await t.pumpAndSettle();
    expect(st.panels.single.needsLogin, isTrue);
    expect(find.textContaining('Вход отозван'), findsOneWidget);
  });

  testWidgets('sign out keeps the subscriptions (unlinked) unless asked to delete them', (t) async {
    final (st, api) = await pumpSubs(t);
    await t.tap(find.text('Войти в панель SolaHelm'));
    await t.pumpAndSettle();
    await signIn(t, 'secret');
    await t.runAsync(() => st.logoutPanel(st.panels.single.id));
    await t.pumpAndSettle();
    expect(api.calls.last, 'logout sht_token');
    expect(st.panels, isEmpty);
    expect(st.subscriptions.single.panelId, isNull);
  });

  testWidgets('self-signed panel: the choice reaches the panel API and the subscription download', (t) async {
    final (st, api) = await pumpSubs(t);
    await t.tap(find.text('Войти в панель SolaHelm'));
    await t.pumpAndSettle();
    await signIn(t, 'secret', selfSigned: true);
    expect(api.calls.last, 'login https://panel.example.org/hy test1 self-signed');
    expect(st.panels.single.insecure, isTrue);
    expect(st.subscriptions.single.insecure, isTrue);
    expect((st.backend as FakeBackend).lastFetchInsecure, isTrue);
  });

  testWidgets('sidebar: a sign-in button, then the signed-in name', (t) async {
    final (st, _) = await pumpSubs(t);
    expect(find.widgetWithText(OutlinedButton, 'Войти в панель'), findsOneWidget);
    await t.tap(find.widgetWithText(OutlinedButton, 'Войти в панель'));
    await t.pumpAndSettle();
    await signIn(t, 'secret');
    expect(find.widgetWithText(OutlinedButton, 'Войти в панель'), findsNothing);
    expect(find.text('Test One'), findsOneWidget);
  });

  testWidgets('phone home: a sign-in button while there are no subscriptions', (t) async {
    final st = AppState(
      Settings(languageCode: 'ru', themeMode: ThemeMode.light, proxyMode: ProxyMode.tun, uiMode: UiMode.simple, welcomeDone: true),
      FakeBackend(random: Random(1), startDelay: const Duration(milliseconds: 50)),
      MemorySubStore(),
    );
    final api = FakePanelApi();
    st.panelApi = api;
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await st.init();
    await t.pumpWidget(SolaHelmApp(state: st));
    await t.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Войти в панель'), findsOneWidget);
    await t.tap(find.widgetWithText(FilledButton, 'Войти в панель').last); // the dialog's button
    await t.pumpAndSettle();
    await signIn(t, 'secret');
    expect(st.subscriptions, hasLength(1));
    expect(find.widgetWithText(FilledButton, 'Войти в панель'), findsNothing);
  });
}
