import 'dart:async';
import 'dart:math';

import '../models.dart';
import 'backend.dart';

/// In-memory core for widget tests and the demo build (--dart-define=DEMO=true).
class FakeBackend implements CoreBackend {
  FakeBackend({Random? random, this.startDelay = const Duration(milliseconds: 300)}) : _rnd = random ?? Random();

  final Random _rnd;
  final Duration startDelay;
  bool _running = false;
  bool _elevated = false;
  int _up = 0, _down = 0;
  final Map<String, String> _selected = {'proxy': 'auto'};

  static const _leaves = {
    'DE-Germany-Hysteria2': 'Hysteria2',
    'DE-Germany-TUIC v5': 'TUIC',
    'FL-Finland-VLESS Reality': 'VLESS',
    'FL-Finland-AnyTLS': 'AnyTLS',
    'US-Lite-Trojan': 'Trojan',
  };

  /// When true, start(mode: tun) fails until elevate() is called.
  bool requireElevationForTun = true;

  @override
  bool get elevated => _elevated;

  @override
  Future<FetchResult> fetch(String url, {CoreKind? prefer, bool insecure = false}) async {
    lastFetchInsecure = insecure;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!url.startsWith('http')) throw CoreException('bad url');
    final clash = url.endsWith('/clash');
    return FetchResult(
      content: clash ? 'proxies: []' : '{"outbounds":[]}',
      format: clash ? SubFormat.clashYaml : SubFormat.singBoxJson,
      core: clash ? CoreKind.mihomo : CoreKind.singBox,
      title: Uri.parse(url).host,
      download: 38 * 1024 * 1024 * 1024,
      total: 100 * 1024 * 1024 * 1024,
      expire: DateTime(2027, 2, 1),
    );
  }

  @override
  Future<CoreStatus> start({
    required String content,
    required CorePref core,
    required ProxyMode mode,
    int port = 0,
    List<String>? rules,
    bool rulesReplace = false,
    Map<String, dynamic>? tuning,
    List<String>? bypass,
    bool findProcess = true,
    String tunStack = 'gvisor',
    String routing = '',
  }) async {
    lastRules = rules;
    lastTuning = tuning;
    lastRouting = routing;
    lastPort = port;
    if (mode == ProxyMode.tun && requireElevationForTun && !_elevated) {
      throw CoreException('needs-elevation: TUN mode requires administrator rights', needsElevation: true);
    }
    await Future<void>.delayed(startDelay);
    _running = true;
    final kind = switch (core) {
      CorePref.singBox => CoreKind.singBox,
      CorePref.mihomo => CoreKind.mihomo,
      CorePref.auto => content.trimLeft().startsWith('{') ? CoreKind.singBox : CoreKind.mihomo,
    };
    return CoreStatus(
      running: true,
      core: kind,
      mode: mode,
      port: port == 0 ? 7890 : port,
      startedAt: DateTime.now(),
      elevated: _elevated,
    );
  }

  /// Rules, tuning and port passed to the last start(), for tests.
  List<String>? lastRules;
  String? lastRouting; // routing template of the last start
  bool? lastFetchInsecure;
  Map<String, dynamic>? lastTuning;
  int? lastPort;

  static const _profileRules = ['DOMAIN-SUFFIX,ya.ru,DIRECT', 'GEOIP,RU,DIRECT,no-resolve', 'MATCH,proxy'];

  @override
  Future<ValidateResult> validate(String content, {List<String>? rules, bool rulesReplace = false, String routing = ''}) async {
    if (content.trim().isEmpty || content.contains('broken')) {
      return const ValidateResult(ok: false, error: 'unrecognized config');
    }
    final bad = rules?.where((l) => RuleLine.parse(l) == null).toList() ?? const [];
    if (bad.isNotEmpty) return ValidateResult(ok: false, error: 'bad rule ${bad.first}');
    final clash = !content.trimLeft().startsWith('{');
    return ValidateResult(
      ok: true,
      format: clash ? SubFormat.clashYaml : SubFormat.singBoxJson,
      core: clash ? CoreKind.mihomo : CoreKind.singBox,
    );
  }

  /// What the fake "QR scan" finds.
  List<String> qrTexts = const [];

  @override
  Future<List<String>> qrScreen() async => qrTexts;

  @override
  Future<List<String>> qrImage(List<int> picture) async => qrTexts;

  @override
  Future<ProfileRulesInfo> profileRules(String content, {String routing = ''}) async => ProfileRulesInfo(
        core: CoreKind.mihomo,
        replace: true,
        rules: _profileRules,
        readOnly: const [],
        targets: ['proxy', 'auto', ..._leaves.keys],
        types: const ['DOMAIN', 'DOMAIN-SUFFIX', 'DOMAIN-KEYWORD', 'IP-CIDR', 'PROCESS-NAME', 'GEOIP', 'MATCH'],
      );

  @override
  Future<List<ProfileRule>> activeRules() async => [
        for (final l in lastRules ?? _profileRules)
          if (RuleLine.parse(l) case final r?) ProfileRule(r.type, r.payload, r.target),
      ];

  @override
  Future<CoreStatus> stop() async {
    if (stopDelay > Duration.zero) await Future<void>.delayed(stopDelay);
    _running = false;
    return const CoreStatus();
  }

  /// When true, elevate() fails like a declined UAC prompt.
  bool denyElevation = false;

  @override
  Future<void> elevate() async {
    if (denyElevation) throw CoreException('declined');
    _elevated = true;
  }

  @override
  Future<ProxySnapshot> proxies() async {
    if (!_running) throw CoreException('The core is not running');
    final leaves = {for (final e in _leaves.entries) e.key: ProxyNode(name: e.key, type: e.value)};
    return ProxySnapshot([
      ProxyGroup(name: 'proxy', type: 'Selector', members: ['auto', ..._leaves.keys], now: _selected['proxy']),
      ProxyGroup(name: 'auto', type: 'URLTest', members: _leaves.keys.toList(), now: _leaves.keys.first),
    ], leaves);
  }

  @override
  Future<int?> delay(String proxy, {Duration timeout = const Duration(seconds: 5)}) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    if (proxy.startsWith('US-')) return null;
    return 40 + _rnd.nextInt(150);
  }

  @override
  Future<void> select(String group, String proxy) async {
    _selected[group] = proxy;
  }

  @override
  Future<TrafficSnapshot> traffic() async {
    _up += 20000 + _rnd.nextInt(80000);
    _down += 300000 + _rnd.nextInt(2000000);
    return TrafficSnapshot(uploadTotal: _up, downloadTotal: _down, connections: [
      for (final c in _conns)
        ConnectionEntry(
          id: c.$1,
          host: c.$2,
          port: '443',
          network: 'tcp',
          inbound: 'Tun',
          rule: c.$4 == 'DIRECT' ? 'RuleSet' : 'Match',
          rulePayload: c.$4 == 'DIRECT' ? 'ru-inline' : '',
          chains: c.$4 == 'DIRECT' ? ['DIRECT'] : [c.$4, 'proxy'],
          upload: _up ~/ 10,
          download: _down ~/ 10,
          start: DateTime.now().subtract(const Duration(minutes: 1)),
          processPath: 'C:\\Program Files\\${c.$3}',
        ),
    ]);
  }

  final List<(String, String, String, String)> _conns = [
    ('c1', 'youtube.com', 'opera.exe', 'DE-Germany-Hysteria2'),
    ('c2', 'ya.ru', 'opera.exe', 'DIRECT'),
    ('c3', 'telegram.org', 'Telegram.exe', 'FL-Finland-AnyTLS'),
  ];

  @override
  Future<void> closeConnection(String id) async => _conns.removeWhere((c) => c.$1 == id);

  @override
  Future<void> closeAllConnections() async => _conns.clear();

  String _mode = 'rule';

  @override
  Future<String?> routingMode() async => _mode;

  @override
  Future<void> setRoutingMode(String mode) async => _mode = mode;

  /// Mimics the core's /logs before its first line: nothing arrives and
  /// cancelling never completes. Disconnect must not wait for it.
  bool hangLogs = false;

  /// Delay inside stop(), to watch the "disconnecting" state.
  Duration stopDelay = Duration.zero;

  @override
  Stream<LogEntry> logs({String level = 'info'}) {
    if (hangLogs) {
      final never = Completer<void>();
      return StreamController<LogEntry>(onCancel: () => never.future).stream;
    }
    return _demoLogs();
  }

  Stream<LogEntry> _demoLogs() async* {
    yield LogEntry('info', '[TCP] 198.18.0.1:52591(curl.exe) --> api.ipify.org:443 match Match using proxy[DE-Germany-Hysteria2]', DateTime.now());
    yield LogEntry('warning', 'demo warning', DateTime.now());
  }

  /// Status attachExisting() reports, for tests.
  CoreStatus? leftRunning;
  bool detached = false;

  @override
  Future<CoreStatus?> attachExisting() async {
    final st = leftRunning;
    if (st != null) _running = true;
    return st;
  }

  @override
  Future<void> detachForExit() async => detached = true;

  @override
  Future<void> dispose() async {}
}
