import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:solahelm_client/core/panel_api.dart';

/// A panel on https with a self-signed certificate (test/fixtures, made for
/// localhost only): refused unless the user ticked "self-signed".
void main() {
  late HttpServer server;
  late String base;

  setUpAll(() async {
    final ctx = SecurityContext()
      ..useCertificateChain('test/fixtures/selfsigned.crt')
      ..usePrivateKey('test/fixtures/selfsigned.key');
    server = await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 0, ctx);
    base = 'https://localhost:${server.port}/hy';
    server.listen((req) async {
      await utf8.decoder.bind(req).join();
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode({
        'ok': true,
        'token': 'sht_tls',
        'panel': {'name': 'SolaHelm', 'version': '1.15.0'},
        'client': {'login': 'test1', 'name': ''},
        'profiles': <Object>[],
      }));
      await req.response.close();
    });
  });

  tearDownAll(() => server.close(force: true));

  test('self-signed certificate: refused by default, accepted when ticked', () async {
    const api = PanelApi();
    await expectLater(api.login(base, 'test1', 'pw'),
        throwsA(isA<PanelException>().having((e) => e.code, 'code', 'certificate')));
    final r = await api.login(base, 'test1', 'pw', selfSigned: true);
    expect(r.token, 'sht_tls');
  });
}
