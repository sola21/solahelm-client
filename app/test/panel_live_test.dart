import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:solahelm_client/core/panel_api.dart';

/// Against a real panel (1.15+). Skipped unless SOLAHELM_PANEL_URL,
/// SOLAHELM_PANEL_LOGIN and SOLAHELM_PANEL_PASSWORD are set.
void main() {
  final env = Platform.environment;
  final url = env['SOLAHELM_PANEL_URL'];
  final skip = url == null ? 'set SOLAHELM_PANEL_URL / _LOGIN / _PASSWORD' : null;

  test('real panel: login, profiles, logout revokes the token', () async {
    const api = PanelApi();
    final base = PanelApi.normalizeUrl(url!);
    final r = await api.login(base, env['SOLAHELM_PANEL_LOGIN']!, env['SOLAHELM_PANEL_PASSWORD']!);
    expect(r.token, startsWith('sht_'));
    expect(r.profiles, isNotEmpty);
    // ignore: avoid_print
    print('panel ${r.panelName} ${r.panelVersion}, client ${r.clientLogin}: '
        '${r.profiles.map((p) => '${p.name}=${p.state}${p.subscriptionUrl == null ? '' : ' (sub)'}').join(', ')}');
    final again = await api.profiles(base, r.token!);
    expect(again.profiles.length, r.profiles.length);
    await api.logout(base, r.token!);
    await expectLater(api.profiles(base, r.token!),
        throwsA(isA<PanelException>().having((e) => e.code, 'code', 'unauthorized')));
    await expectLater(api.login(base, env['SOLAHELM_PANEL_LOGIN']!, 'wrong password'),
        throwsA(isA<PanelException>().having((e) => e.code, 'code', 'bad_credentials')));
  }, skip: skip);
}
