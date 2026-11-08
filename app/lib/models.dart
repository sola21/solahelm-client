import 'package:flutter/foundation.dart';

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

/// How much of the app is shown: [simple] is one button and a server list,
/// [advanced] is everything. null in Settings = not chosen yet (first start).
enum UiMode { simple, advanced }

/// Where the traffic comes out: the public IP seen through the VPN.
@immutable
class ExitInfo {
  const ExitInfo({required this.ip, this.countryCode, this.country, this.city});

  final String ip;
  final String? countryCode; // ISO 3166-1 alpha-2, upper case
  final String? country; // in the UI language when the service supports it
  final String? city;

  /// "203.0.*.*" (IPv4) or "2a01:4f8:*" (IPv6): enough to recognise, not to copy.
  String get masked {
    if (ip.contains('.') && !ip.contains(':')) {
      final p = ip.split('.');
      return p.length == 4 ? '${p[0]}.${p[1]}.*.*' : ip;
    }
    final p = ip.split(':');
    return p.length > 2 ? '${p[0]}:${p[1]}:*' : ip;
  }

  /// "США, Лос-Анджелес", or whatever is known.
  String get place => [country ?? countryCode, city].whereType<String>().where((e) => e.isNotEmpty).join(', ');
}

enum LinkStatus {
  disconnected,
  connecting,
  connected,
  disconnecting;

  /// Connecting or disconnecting: the connect button is disabled meanwhile.
  bool get busy => this == connecting || this == disconnecting;
}

/// Where a profile comes from.
enum SubSource { remote, file, pasted }

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
    this.unsupported = const [],
    this.upload = 0,
    this.download = 0,
    this.total = 0,
    this.expire,
    this.updatedAt,
    this.error,
    this.source = SubSource.remote,
    this.edited = false,
    this.rules,
    this.rulesReplace = false,
  });

  final String id;
  final String name;
  final String url;
  final SubFormat? format; // null: not downloaded yet
  final CoreKind? core; // what auto-detection picked
  final List<String> protocols;
  final int linkCount;
  final List<String> unsupported; // link protocols that were skipped
  final int upload, download, total; // bytes; total 0 = unlimited
  final DateTime? expire; // null: never
  final DateTime? updatedAt;
  final String? error; // last update error
  final SubSource source; // url holds the link, or the file path for files
  final bool edited; // changed by hand; a refresh would overwrite it
  /// User rules in Clash syntax kept apart from the profile, so a refresh
  /// doesn't lose them. null = the profile's own rules as they are.
  final List<String>? rules;
  /// rules replace the profile's list (mihomo) instead of going in front (sing-box).
  final bool rulesReplace;

  bool get refreshable => source != SubSource.pasted;

  Subscription copyWith({
    String? name,
    bool? edited,
    SubFormat? format,
    CoreKind? core,
    DateTime? updatedAt,
    List<String>? protocols,
    int? linkCount,
    List<String>? unsupported,
    List<String>? Function()? rules,
    bool? rulesReplace,
  }) =>
      Subscription(
        id: id,
        name: name ?? this.name,
        url: url,
        format: format ?? this.format,
        core: core ?? this.core,
        protocols: protocols ?? this.protocols,
        linkCount: linkCount ?? this.linkCount,
        unsupported: unsupported ?? this.unsupported,
        upload: upload,
        download: download,
        total: total,
        expire: expire,
        updatedAt: updatedAt ?? this.updatedAt,
        error: error,
        source: source,
        edited: edited ?? this.edited,
        rules: rules == null ? this.rules : rules(),
        rulesReplace: rulesReplace ?? this.rulesReplace,
      );

  bool get loaded => format != null;
  static const _gb = 1024 * 1024 * 1024;
  double? get usedGb => loaded ? (upload + download) / _gb : null;
  double? get totalGb => total > 0 ? total / _gb : null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'format': format?.name,
        'core': core?.name,
        'protocols': protocols,
        'linkCount': linkCount,
        'unsupported': unsupported,
        'upload': upload,
        'download': download,
        'total': total,
        'expire': expire?.millisecondsSinceEpoch,
        'updatedAt': updatedAt?.millisecondsSinceEpoch,
        'error': error,
        'source': source.name,
        'edited': edited,
        'rules': rules,
        'rulesReplace': rulesReplace,
      };

  static Subscription fromJson(Map<String, dynamic> m) => Subscription(
        id: m['id'] as String,
        name: m['name'] as String,
        url: m['url'] as String,
        format: SubFormat.values.asNameMap()[m['format']],
        core: CoreKind.values.asNameMap()[m['core']],
        protocols: (m['protocols'] as List?)?.cast<String>() ?? const [],
        linkCount: (m['linkCount'] as num?)?.toInt() ?? 0,
        unsupported: (m['unsupported'] as List?)?.cast<String>() ?? const [],
        upload: (m['upload'] as num?)?.toInt() ?? 0,
        download: (m['download'] as num?)?.toInt() ?? 0,
        total: (m['total'] as num?)?.toInt() ?? 0,
        expire: _date(m['expire']),
        updatedAt: _date(m['updatedAt']),
        error: m['error'] as String?,
        source: SubSource.values.asNameMap()[m['source']] ?? SubSource.remote,
        edited: m['edited'] as bool? ?? false,
        rules: (m['rules'] as List?)?.map((e) => e.toString()).toList(),
        rulesReplace: m['rulesReplace'] as bool? ?? false,
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

/// A rule of the running profile, as the core reports it.
class ProfileRule {
  const ProfileRule(this.type, this.payload, this.proxy);
  final String type;
  final String payload;
  final String proxy;
}

/// What the rules editor works with, from the core (`/profile-rules`).
class ProfileRulesInfo {
  const ProfileRulesInfo({
    required this.core,
    required this.replace,
    required this.rules,
    required this.readOnly,
    required this.targets,
    required this.types,
  });
  final CoreKind? core;
  final bool replace; // true: the editor owns the whole list (mihomo)
  final List<String> rules; // the profile's own editable lines
  final List<String> readOnly; // sing-box: the profile's rules, described
  final List<String> targets; // groups and proxies
  final List<String> types; // rule types to offer
}

/// Result of checking a config (and rules) with the core, without starting it.
class ValidateResult {
  const ValidateResult({
    required this.ok,
    this.format,
    this.core,
    this.error,
    this.converted = 0,
    this.protocols = const [],
    this.linkCount = 0,
    this.unsupported = const [],
  });
  final bool ok;
  final SubFormat? format;
  final CoreKind? core;
  final String? error;
  final int converted; // proxies made from share links
  final List<String> protocols;
  final int linkCount;
  final List<String> unsupported; // link protocols the core can't run (skipped)
}

/// One Clash rule line split into its parts.
class RuleLine {
  const RuleLine({required this.type, this.payload = '', required this.target, this.noResolve = false});

  final String type;
  final String payload;
  final String target;
  final bool noResolve;

  static const ipTypes = {'IP-CIDR', 'IP-CIDR6', 'IP-SUFFIX', 'IP-ASN', 'GEOIP', 'SRC-IP-CIDR'};
  bool get canNoResolve => ipTypes.contains(type);

  static RuleLine? parse(String line) {
    final parts = line.split(',').map((e) => e.trim()).toList();
    if (parts.isEmpty || parts.first.isEmpty) return null;
    final type = parts.first.toUpperCase();
    if (type == 'MATCH' || type == 'FINAL') {
      return parts.length >= 2 ? RuleLine(type: 'MATCH', target: parts[1]) : null;
    }
    if (parts.length < 3) return null;
    return RuleLine(
      type: type,
      payload: parts[1],
      target: parts[2],
      noResolve: parts.skip(3).any((e) => e.toLowerCase() == 'no-resolve'),
    );
  }

  @override
  String toString() =>
      type == 'MATCH' ? 'MATCH,$target' : '$type,$payload,$target${noResolve && canNoResolve ? ',no-resolve' : ''}';
}
