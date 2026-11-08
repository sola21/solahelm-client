import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models.dart';

/// Asks a public "what is my IP" service which IP and country the traffic
/// comes out with. The request goes through the core's local proxy port, so
/// it takes the same way as everything else (on Android the app itself is
/// outside the VPN). Tries a few services; null when none answered.
Future<ExitInfo?> lookupExit({required int proxyPort, String lang = 'en'}) async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 6)
    ..userAgent = 'SolaHelm-Client'
    ..findProxy = (_) => 'PROXY 127.0.0.1:$proxyPort';
  try {
    for (final source in _sources) {
      try {
        final m = await _getJson(client, source.url(lang));
        final info = source.parse(m);
        if (info != null && info.ip.isNotEmpty) return info;
      } catch (_) {
        // Next service.
      }
    }
    return null;
  } finally {
    client.close(force: true);
  }
}

class _Source {
  const _Source(this.url, this.parse);
  final Uri Function(String lang) url;
  final ExitInfo? Function(Map<String, dynamic> m) parse;
}

String? _str(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
String? _code(Object? v) => _str(v)?.toUpperCase();

final _sources = <_Source>[
  // Country and city in the UI language.
  _Source(
    (lang) => Uri.parse('https://ipwho.is/?lang=$lang'),
    (m) => m['success'] == false
        ? null
        : ExitInfo(ip: _str(m['ip']) ?? '', countryCode: _code(m['country_code']), country: _str(m['country']), city: _str(m['city'])),
  ),
  _Source(
    (_) => Uri.parse('https://ipinfo.io/json'),
    (m) => ExitInfo(ip: _str(m['ip']) ?? '', countryCode: _code(m['country']), city: _str(m['city'])),
  ),
  _Source(
    (_) => Uri.parse('https://api.ip.sb/geoip'),
    (m) => ExitInfo(ip: _str(m['ip']) ?? '', countryCode: _code(m['country_code']), country: _str(m['country']), city: _str(m['city'])),
  ),
];

Future<Map<String, dynamic>> _getJson(HttpClient client, Uri url) async {
  final req = await client.getUrl(url).timeout(const Duration(seconds: 6));
  req.headers.set(HttpHeaders.acceptHeader, 'application/json');
  final res = await req.close().timeout(const Duration(seconds: 8));
  final body = await res.transform(utf8.decoder).join().timeout(const Duration(seconds: 8));
  if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}', uri: url);
  return (jsonDecode(body) as Map).cast<String, dynamic>();
}
