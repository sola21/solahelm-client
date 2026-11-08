enum CoreKind {
  singBox('sing-box'),
  mihomo('mihomo');

  const CoreKind(this.label);
  final String label;
}

/// User's choice in settings: let the app decide, or pin one core.
enum CorePref { auto, singBox, mihomo }

enum SubFormat { singBoxJson, clashYaml, links }

enum ProxyMode { tun, systemProxy, portOnly }

enum LinkStatus { disconnected, connecting, connected }

/// One proxy server entry from the core (a leaf, not a group).
class ProxyNode {
  ProxyNode({required this.name, required this.type, this.delayMs});

  final String name;
  final String type; // Hysteria2, VLESS, ...
  int? delayMs; // null: not measured yet
  bool timedOut = false;
  bool measuring = false;
}

/// Selector / URLTest / Fallback group from the core.
class ProxyGroup {
  const ProxyGroup({required this.name, required this.type, required this.members, this.now});

  final String name;
  final String type;
  final List<String> members;
  final String? now; // currently used member

  /// Only Selector groups accept a manual choice.
  bool get selectable => type.toLowerCase() == 'selector';
}

class Subscription {
  Subscription({
    required this.id,
    required this.name,
    required this.url,
    this.format,
    this.core,
    this.protocols = const [],
    this.linkCount = 0,
    this.upload = 0,
    this.download = 0,
    this.total = 0,
    this.expire,
    this.updatedAt,
    this.error,
  });

  final String id;
  final String name;
  final String url;
  final SubFormat? format; // null: not downloaded yet
  final CoreKind? core; // what auto-detection picked
  final List<String> protocols;
  final int linkCount;
  final int upload, download, total; // bytes; total 0 = unlimited
  final DateTime? expire; // null: never
  final DateTime? updatedAt;
  final String? error; // last update error

  bool get loaded => format != null;
  static const _gb = 1024 * 1024 * 1024;
  double? get usedGb => loaded ? (upload + download) / _gb : null;
  double? get totalGb => total > 0 ? total / _gb : null;

  /// A protocol that only one core supports and so forced the choice.
  String? get onlyProtocol {
    if (protocols.contains('naive')) return 'Naive';
    if (protocols.contains('shadowsocksr')) return 'ShadowsocksR';
    if (protocols.contains('mieru')) return 'Mieru';
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'format': format?.name,
        'core': core?.name,
        'protocols': protocols,
        'linkCount': linkCount,
        'upload': upload,
        'download': download,
        'total': total,
        'expire': expire?.millisecondsSinceEpoch,
        'updatedAt': updatedAt?.millisecondsSinceEpoch,
        'error': error,
      };

  static Subscription fromJson(Map<String, dynamic> m) => Subscription(
        id: m['id'] as String,
        name: m['name'] as String,
        url: m['url'] as String,
        format: SubFormat.values.asNameMap()[m['format']],
        core: CoreKind.values.asNameMap()[m['core']],
        protocols: (m['protocols'] as List?)?.cast<String>() ?? const [],
        linkCount: (m['linkCount'] as num?)?.toInt() ?? 0,
        upload: (m['upload'] as num?)?.toInt() ?? 0,
        download: (m['download'] as num?)?.toInt() ?? 0,
        total: (m['total'] as num?)?.toInt() ?? 0,
        expire: _date(m['expire']),
        updatedAt: _date(m['updatedAt']),
        error: m['error'] as String?,
      );

  static DateTime? _date(Object? v) => v is num ? DateTime.fromMillisecondsSinceEpoch(v.toInt()) : null;
}

/// One connection reported by the core (Clash API /connections).
class ConnectionEntry {
  ConnectionEntry({
    this.id = '',
    required this.host,
    this.port = '',
    this.destIp = '',
    this.srcIp = '',
    this.srcPort = '',
    this.network = '',
    this.inbound = '',
    this.rule = '',
    this.rulePayload = '',
    this.chains = const [],
    this.upload = 0,
    this.download = 0,
    this.start,
    this.processPath = '',
    this.process = '',
    this.remote = '',
  });

  final String id;
  final String host; // domain, or IP when there is no domain
  final String port;
  final String destIp, srcIp, srcPort;
  final String network; // tcp / udp
  final String inbound; // Tun, Mixed, ...
  final String rule, rulePayload;
  final List<String> chains; // innermost first: [node, group, ...]
  int upload, download;
  final DateTime? start;
  final String processPath;
  final String process;
  final String remote; // remote destination as the proxy saw it

  // Filled by the UI between polls.
  int upSpeed = 0, downSpeed = 0;
  DateTime? closedAt;

  bool get active => closedAt == null;
  String get hostPort => port.isEmpty ? host : '$host:$port';
  bool get direct => chains.isEmpty || chains.first.toUpperCase() == 'DIRECT';

  /// "group → node", like Koala Clash shows it.
  String get chain => chains.isEmpty ? 'DIRECT' : chains.reversed.join(' → ');

  /// Executable name, e.g. "Telegram.exe"; falls back to the source address.
  String get app {
    if (process.isNotEmpty) return process;
    var p = processPath;
    final paren = p.indexOf(' (');
    if (paren > 0) p = p.substring(0, paren);
    if (p.isNotEmpty) {
      final back = p.lastIndexOf(r'\');
      final slash = p.lastIndexOf('/');
      final i = back > slash ? back : slash;
      return i >= 0 ? p.substring(i + 1) : p;
    }
    return srcIp.isEmpty ? '?' : srcIp;
  }

  String get ruleText => rulePayload.isEmpty ? rule : '$rule($rulePayload)';
}

class LogEntry {
  LogEntry(this.level, this.message, this.time);
  final String level; // debug, info, warning, error
  final String message;
  final DateTime time;
}
