import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../models.dart';
import 'backend.dart';

/// Runs solahelm-core (`serve`) as a separate process and talks to it, and to
/// the core's Clash API, over loopback HTTP.
class DaemonBackend implements CoreBackend {
  DaemonBackend({required this.executable, required this.workDir});

  final String executable;
  final String workDir;

  final HttpClient _http = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  Uri? _base;
  String _secret = '';
  Uri? _clash;
  String _clashSecret = '';
  bool _elevated = false;
  Process? _process;
  Future<void>? _starting;

  @override
  bool get elevated => _elevated;

  /// Finds solahelm-core next to the app (or SOLAHELM_CORE for development).
  static String? locate() {
    final override = Platform.environment['SOLAHELM_CORE'];
    if (override != null && File(override).existsSync()) return override;
    final dir = File(Platform.resolvedExecutable).parent.path;
    final name = Platform.isWindows ? 'solahelm-core.exe' : 'solahelm-core';
    final f = File('$dir${Platform.pathSeparator}$name');
    return f.existsSync() ? f.path : null;
  }

  Future<void> _ensure() => _starting ??= _launch(elevated: false);

  Future<void> _launch({required bool elevated}) async {
    final tmp = await Directory.systemTemp.createTemp('solahelm-');
    final secretFile = File('${tmp.path}${Platform.pathSeparator}secret');
    final readyFile = File('${tmp.path}${Platform.pathSeparator}ready');
    final rnd = Random.secure();
    final secret = List.generate(32, (_) => rnd.nextInt(16).toRadixString(16)).join();
    await secretFile.writeAsString(secret, flush: true);
    await Directory(workDir).create(recursive: true);

    final args = [
      'serve',
      '-secret-file', secretFile.path,
      '-ready-file', readyFile.path,
      '-parent', '$pid',
      '-workdir', workDir,
    ];
    if (!elevated) {
      _process = await Process.start(executable, args);
      _process!.stderr.drain<void>();
      _process!.stdout.drain<void>();
    } else {
      await _startElevated(args);
    }

    // Wait for the address (UAC may take a while for the user to answer).
    final deadline = DateTime.now().add(Duration(seconds: elevated ? 90 : 15));
    while (!await readyFile.exists() || (await readyFile.length()) == 0) {
      if (DateTime.now().isAfter(deadline)) {
        throw CoreException(elevated
            ? 'The core was not started with administrator rights'
            : 'The core did not start');
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    final addr = (await readyFile.readAsString()).trim();
    _base = Uri.parse('http://$addr');
    _secret = secret;
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
    final st = await _call('GET', '/status');
    _elevated = st['elevated'] == true;
  }

  Future<void> _startElevated(List<String> args) async {
    if (!Platform.isWindows) {
      throw CoreException('Administrator mode is only implemented on Windows so far');
    }
    String q(String s) => '"${s.replaceAll('"', r'\"')}"';
    String ps(String s) => "'${s.replaceAll("'", "''")}'";
    final argLine = args.map((a) => a.startsWith('-') || a == 'serve' ? a : q(a)).join(' ');
    final cmd = 'Start-Process -FilePath ${ps(executable)} -ArgumentList ${ps(argLine)} -Verb RunAs -WindowStyle Hidden';
    final r = await Process.run('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command', cmd]);
    if (r.exitCode != 0) {
      throw CoreException('The administrator request was declined');
    }
  }

  @override
  Future<void> elevate() async {
    await _shutdownDaemon();
    _starting = _launch(elevated: true);
    try {
      await _starting;
    } catch (_) {
      _starting = null; // fall back to a normal core next time
      rethrow;
    }
  }

  Future<void> _shutdownDaemon() async {
    if (_base != null) {
      try {
        await _call('POST', '/shutdown');
      } catch (_) {}
    }
    _process?.kill();
    _process = null;
    _base = null;
    _clash = null;
    _starting = null;
    _elevated = false;
  }

  Future<Map<String, dynamic>> _call(String method, String path, [Object? body]) async {
    final base = _base;
    if (base == null) throw CoreException('The core is not running');
    return _request(base.resolve(path), method, _secret, body);
  }

  Future<Map<String, dynamic>> _request(Uri uri, String method, String secret, [Object? body]) async {
    final req = await _http.openUrl(method, uri);
    req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $secret');
    if (body != null) {
      req.headers.contentType = ContentType.json;
      req.add(utf8.encode(jsonEncode(body)));
    }
    final resp = await req.close().timeout(const Duration(seconds: 45));
    final text = await resp.transform(utf8.decoder).join();
    final decoded = text.isEmpty ? <String, dynamic>{} : jsonDecode(text);
    final map = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{'value': decoded};
    if (resp.statusCode >= 400) {
      final msg = (map['error'] ?? map['message'] ?? 'HTTP ${resp.statusCode}').toString();
      throw CoreException(msg, needsElevation: msg.startsWith('needs-elevation'));
    }
    return map;
  }

  @override
  Future<FetchResult> fetch(String url, {CoreKind? prefer}) async {
    await _ensure();
    final m = await _call('POST', '/fetch', {'url': url, 'prefer': prefer?.label ?? ''});
    final det = m['detect'] as Map<String, dynamic>?;
    final expire = (m['expire'] as num?)?.toInt() ?? 0;
    return FetchResult(
      content: m['content'] as String? ?? '',
      format: parseFormat(det?['format'] as String?),
      core: parseCore(det?['core'] as String?),
      protocols: (det?['protocols'] as List?)?.cast<String>() ?? const [],
      title: (m['title'] as String?)?.trim().isEmpty ?? true ? null : m['title'] as String,
      upload: (m['upload'] as num?)?.toInt() ?? 0,
      download: (m['download'] as num?)?.toInt() ?? 0,
      total: (m['total'] as num?)?.toInt() ?? 0,
      expire: expire > 0 ? DateTime.fromMillisecondsSinceEpoch(expire * 1000) : null,
      error: m['error'] as String?,
    );
  }

  CoreStatus _status(Map<String, dynamic> m) {
    final started = m['startedAt'] as String?;
    final ctrl = m['controller'] as String?;
    if (ctrl != null && ctrl.isNotEmpty) {
      _clash = Uri.parse('http://$ctrl');
      _clashSecret = m['controllerSecret'] as String? ?? '';
    } else {
      _clash = null;
    }
    _elevated = m['elevated'] == true;
    return CoreStatus(
      running: m['running'] == true,
      core: parseCore(m['core'] as String?),
      mode: parseMode(m['mode'] as String?),
      port: (m['port'] as num?)?.toInt(),
      startedAt: started == null ? null : DateTime.tryParse(started)?.toLocal(),
      elevated: _elevated,
      error: m['error'] as String?,
      versions: (m['version'] as Map?)?.cast<String, String>() ?? const {},
    );
  }

  @override
  Future<CoreStatus> start({
    required String content,
    required CorePref core,
    required ProxyMode mode,
    int port = 0,
  }) async {
    await _ensure();
    final m = await _call('POST', '/start', {
      'content': content,
      'core': switch (core) {
        CorePref.auto => 'auto',
        CorePref.singBox => 'sing-box',
        CorePref.mihomo => 'mihomo',
      },
      'mode': modeWire(mode),
      'port': port,
    });
    return _status(m);
  }

  @override
  Future<CoreStatus> stop() async {
    if (_base == null) return const CoreStatus();
    return _status(await _call('POST', '/stop'));
  }

  Future<Map<String, dynamic>> _clashCall(String method, String path, [Object? body]) {
    final c = _clash;
    if (c == null) throw CoreException('The core is not running');
    return _request(c.resolve(path), method, _clashSecret, body);
  }

  @override
  Future<ProxySnapshot> proxies() async {
    final m = await _clashCall('GET', '/proxies');
    final all = (m['proxies'] as Map?)?.cast<String, dynamic>() ?? {};
    final groups = <ProxyGroup>[];
    final leaves = <String, ProxyNode>{};
    const builtin = {'direct', 'reject', 'rejectdrop', 'compatible', 'pass', 'passrule', 'dns', 'block'};
    all.forEach((name, v) {
      final p = (v as Map).cast<String, dynamic>();
      final type = p['type'] as String? ?? '';
      final members = (p['all'] as List?)?.cast<String>();
      if (members != null && members.isNotEmpty) {
        if (name != 'GLOBAL') {
          groups.add(ProxyGroup(name: name, type: type, members: members, now: p['now'] as String?));
        }
      } else if (!builtin.contains(type.toLowerCase())) {
        final history = (p['history'] as List?) ?? const [];
        final last = history.isEmpty ? null : (history.last as Map)['delay'] as num?;
        leaves[name] = ProxyNode(name: name, type: type, delayMs: (last == null || last == 0) ? null : last.toInt());
      }
    });
    // Selectors first: they are the ones the user can switch.
    groups.sort((a, b) => (a.selectable == b.selectable) ? 0 : (a.selectable ? -1 : 1));
    return ProxySnapshot(groups, leaves);
  }

  @override
  Future<int?> delay(String proxy, {Duration timeout = const Duration(seconds: 5)}) async {
    final q = 'url=${Uri.encodeQueryComponent('https://www.gstatic.com/generate_204')}&timeout=${timeout.inMilliseconds}';
    try {
      final m = await _clashCall('GET', '/proxies/${Uri.encodeComponent(proxy)}/delay?$q');
      final d = (m['delay'] as num?)?.toInt();
      return (d == null || d == 0) ? null : d;
    } on CoreException {
      return null;
    }
  }

  @override
  Future<void> select(String group, String proxy) async {
    await _clashCall('PUT', '/proxies/${Uri.encodeComponent(group)}', {'name': proxy});
  }

  @override
  Future<TrafficSnapshot> traffic() async {
    final m = await _clashCall('GET', '/connections');
    final list = (m['connections'] as List?) ?? const [];
    final conns = <ConnectionEntry>[];
    String str(Object? v) => v == null ? '' : v.toString();
    for (final c in list) {
      final cm = (c as Map).cast<String, dynamic>();
      final meta = (cm['metadata'] as Map?)?.cast<String, dynamic>() ?? {};
      final destIp = str(meta['destinationIP']);
      var host = str(meta['host']);
      if (host.isEmpty) host = str(meta['sniffHost']);
      if (host.isEmpty) host = destIp.isEmpty ? '?' : destIp;
      conns.add(ConnectionEntry(
        id: str(cm['id']),
        host: host,
        port: str(meta['destinationPort']),
        destIp: destIp,
        srcIp: str(meta['sourceIP']),
        srcPort: str(meta['sourcePort']),
        network: str(meta['network']),
        inbound: str(meta['type']),
        rule: str(cm['rule']),
        rulePayload: str(cm['rulePayload']),
        chains: (cm['chains'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        upload: (cm['upload'] as num?)?.toInt() ?? 0,
        download: (cm['download'] as num?)?.toInt() ?? 0,
        start: DateTime.tryParse(str(cm['start']))?.toLocal(),
        processPath: str(meta['processPath']),
        process: str(meta['process']),
        remote: str(meta['remoteDestination']),
      ));
    }
    return TrafficSnapshot(
      uploadTotal: (m['uploadTotal'] as num?)?.toInt() ?? 0,
      downloadTotal: (m['downloadTotal'] as num?)?.toInt() ?? 0,
      connections: conns,
    );
  }

  @override
  Future<void> closeConnection(String id) async {
    await _clashCall('DELETE', '/connections/${Uri.encodeComponent(id)}');
  }

  @override
  Future<String?> routingMode() async {
    final m = await _clashCall('GET', '/configs');
    return (m['mode'] as String?)?.toLowerCase();
  }

  @override
  Future<void> setRoutingMode(String mode) async {
    await _clashCall('PATCH', '/configs', {'mode': mode});
  }

  @override
  Future<void> closeAllConnections() async {
    await _clashCall('DELETE', '/connections');
  }

  @override
  Stream<LogEntry> logs({String level = 'info'}) async* {
    final c = _clash;
    if (c == null) return;
    final client = HttpClient();
    try {
      final req = await client.getUrl(c.resolve('/logs?level=$level'));
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_clashSecret');
      final resp = await req.close();
      await for (final line in resp.transform(utf8.decoder).transform(const LineSplitter())) {
        if (line.trim().isEmpty) continue;
        try {
          final m = jsonDecode(line) as Map<String, dynamic>;
          yield LogEntry((m['type'] ?? 'info').toString(), (m['payload'] ?? '').toString(), DateTime.now());
        } catch (_) {
          yield LogEntry('info', line, DateTime.now());
        }
      }
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<void> dispose() async {
    await _shutdownDaemon();
    _http.close(force: true);
  }
}
