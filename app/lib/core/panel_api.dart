import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models.dart';

/// A failed panel request. [code] is what the app shows a message for:
/// bad_url, insecure, network, certificate, not_a_panel, bad_credentials,
/// rate_limited, unauthorized, bad_request, server.
class PanelException implements Exception {
  PanelException(this.code, [this.detail = '']);
  final String code;
  final String detail;

  @override
  String toString() => detail.isEmpty ? code : '$code: $detail';
}

/// What the panel answered to a login or a profiles request.
class PanelReply {
  PanelReply({
    required this.panelName,
    required this.panelVersion,
    required this.clientLogin,
    required this.clientName,
    required this.profiles,
    this.token,
  });
  final String panelName, panelVersion, clientLogin, clientName;
  final List<PanelProfile> profiles;
  final String? token; // login only
}

/// The SolaHelm panel's app API (panel 1.15+): BASE/api/app/{login,profiles,logout}.
class PanelApi {
  const PanelApi();

  /// "panel.example.org/hy/", "https://panel.example.org/hy/login" -> "https://panel.example.org/hy".
  /// Throws bad_url, or insecure for plain http (allowed only for this computer).
  static String normalizeUrl(String input) {
    var s = input.trim();
    if (s.isEmpty) throw PanelException('bad_url');
    if (!s.contains('://')) s = 'https://$s';
    final u = Uri.tryParse(s);
    if (u == null || u.host.isEmpty || (u.scheme != 'https' && u.scheme != 'http')) throw PanelException('bad_url');
    if (u.scheme == 'http' && !const {'localhost', '127.0.0.1', '::1'}.contains(u.host)) {
      throw PanelException('insecure');
    }
    var path = u.path.replaceAll(RegExp(r'/+$'), '');
    for (final tail in const ['/login', '/api/app/login', '/api/app']) {
      if (path.endsWith(tail)) path = path.substring(0, path.length - tail.length);
    }
    return Uri(scheme: u.scheme, host: u.host, port: u.hasPort ? u.port : null, path: path).toString();
  }

  /// A name for this device in the panel's "Connected apps".
  static String deviceName() {
    final os = Platform.isAndroid ? 'Android' : Platform.isWindows ? 'Windows' : Platform.operatingSystem;
    String host = '';
    try {
      host = Platform.localHostname;
    } catch (_) {}
    return ['SolaHelm Client', os, if (host.isNotEmpty && host != 'localhost') host].join(' · ');
  }

  /// [selfSigned]: the user accepted a self-signed certificate for this panel.
  Future<PanelReply> login(String url, String login, String password, {bool selfSigned = false}) async {
    final m = await _call('POST', '$url/api/app/login',
        body: {'login': login, 'password': password, 'device': deviceName()}, selfSigned: selfSigned);
    final r = _reply(m);
    if (r.token == null || r.token!.isEmpty) throw PanelException('not_a_panel');
    return r;
  }

  Future<PanelReply> profiles(String url, String token, {bool selfSigned = false}) async =>
      _reply(await _call('GET', '$url/api/app/profiles', token: token, selfSigned: selfSigned));

  Future<void> logout(String url, String token, {bool selfSigned = false}) async {
    await _call('POST', '$url/api/app/logout', token: token, body: const {}, selfSigned: selfSigned);
  }

  PanelReply _reply(Map<String, dynamic> m) {
    final panel = (m['panel'] as Map?)?.cast<String, dynamic>() ?? const {};
    final client = (m['client'] as Map?)?.cast<String, dynamic>() ?? const {};
    final list = m['profiles'];
    if (list is! List) throw PanelException('not_a_panel');
    return PanelReply(
      panelName: (panel['name'] ?? 'SolaHelm').toString(),
      panelVersion: (panel['version'] ?? '').toString(),
      clientLogin: (client['login'] ?? '').toString(),
      clientName: (client['name'] ?? '').toString(),
      profiles: list.map((e) => PanelProfile.fromJson((e as Map).cast<String, dynamic>())).toList(),
      token: m['token'] as String?,
    );
  }

  Future<Map<String, dynamic>> _call(String method, String url,
      {String? token, Map<String, dynamic>? body, bool selfSigned = false}) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..userAgent = 'SolaHelm-Client';
    // Only when the user ticked "the panel has a self-signed certificate".
    if (selfSigned) client.badCertificateCallback = (_, _, _) => true;
    try {
      final req = await client.openUrl(method, Uri.parse(url)).timeout(const Duration(seconds: 15));
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (token != null) req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      if (body != null) {
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode(body));
      }
      final res = await req.close().timeout(const Duration(seconds: 20));
      final text = await res.transform(utf8.decoder).join().timeout(const Duration(seconds: 20));
      Map<String, dynamic>? m;
      try {
        final d = jsonDecode(text);
        if (d is Map) m = d.cast<String, dynamic>();
      } catch (_) {}
      if (m == null) {
        // An HTML page or nginx's 404: not a SolaHelm panel, or a panel older than 1.15.
        throw PanelException('not_a_panel', 'HTTP ${res.statusCode}');
      }
      if (res.statusCode != 200 || m['ok'] != true) {
        final code = (m['error'] ?? '').toString();
        throw PanelException(code.isNotEmpty ? code : 'server', 'HTTP ${res.statusCode}');
      }
      return m;
    } on PanelException {
      rethrow;
    } on HandshakeException catch (e) {
      // Usually an untrusted (self-signed) certificate.
      throw PanelException(selfSigned ? 'network' : 'certificate', e.message);
    } on SocketException catch (e) {
      throw PanelException('network', e.message);
    } on TimeoutException {
      throw PanelException('network', 'timeout');
    } on HttpException catch (e) {
      throw PanelException('network', e.message);
    } finally {
      client.close(force: true);
    }
  }
}
