import '../models.dart';

/// Error from the core. [needsElevation] means TUN was asked for while the core
/// runs without admin rights; the UI then offers to restart it elevated.
class CoreException implements Exception {
  CoreException(this.message, {this.needsElevation = false});
  final String message;
  final bool needsElevation;

  @override
  String toString() => message;
}

class FetchResult {
  FetchResult({
    required this.content,
    this.format,
    this.core,
    this.protocols = const [],
    this.linkCount = 0,
    this.title,
    this.upload = 0,
    this.download = 0,
    this.total = 0,
    this.expire,
    this.error,
  });

  final String content;
  final SubFormat? format;
  final CoreKind? core;
  final List<String> protocols;
  final int linkCount;
  final String? title;
  final int upload, download, total;
  final DateTime? expire;
  final String? error; // content isn't a known format
}

class CoreStatus {
  const CoreStatus({
    this.running = false,
    this.core,
    this.mode,
    this.port,
    this.startedAt,
    this.elevated = false,
    this.error,
    this.versions = const {},
  });

  final bool running;
  final CoreKind? core;
  final ProxyMode? mode;
  final int? port;
  final DateTime? startedAt;
  final bool elevated;
  final String? error;
  final Map<String, String> versions;
}

class ProxySnapshot {
  const ProxySnapshot(this.groups, this.leaves);
  final List<ProxyGroup> groups;
  final Map<String, ProxyNode> leaves; // by name
}

class TrafficSnapshot {
  const TrafficSnapshot({required this.uploadTotal, required this.downloadTotal, required this.connections});
  final int uploadTotal, downloadTotal;
  final List<ConnectionEntry> connections;
}

/// What the UI needs from a core. The real one talks to solahelm-core and the
/// core's Clash API; FakeBackend drives tests and the demo.
abstract class CoreBackend {
  bool get elevated;
  Future<FetchResult> fetch(String url, {CoreKind? prefer});
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
  });
  Future<CoreStatus> stop();

  /// Checks a config (with optional user rules) without starting it.
  Future<ValidateResult> validate(String content, {List<String>? rules, bool rulesReplace = false});

  /// Rules and possible targets of a profile, for the rules editor.
  Future<ProfileRulesInfo> profileRules(String content);

  /// Rules of the running core (Clash API /rules).
  Future<List<ProfileRule>> activeRules();

  /// Restarts the core process with admin rights (UAC prompt on Windows).
  Future<void> elevate();
  Future<ProxySnapshot> proxies();
  Future<int?> delay(String proxy, {Duration timeout = const Duration(seconds: 5)});
  Future<void> select(String group, String proxy);
  Future<TrafficSnapshot> traffic();
  Future<void> closeConnection(String id);

  /// Clash routing mode: rule, global or direct.
  Future<String?> routingMode();
  Future<void> setRoutingMode(String mode);
  Future<void> closeAllConnections();

  /// Finds a core left running by "exit, keep the core" and takes it over.
  /// Returns its status, or null when there is none.
  Future<CoreStatus?> attachExisting();

  /// Lets the core keep running after the app exits.
  Future<void> detachForExit();

  /// Live log lines from the running core; ends when the core stops.
  Stream<LogEntry> logs({String level = 'info'});
  Future<void> dispose();
}

SubFormat? parseFormat(String? f) => switch (f) {
      'sing-box-json' => SubFormat.singBoxJson,
      'clash-yaml' => SubFormat.clashYaml,
      'share-links' => SubFormat.links,
      _ => null,
    };

CoreKind? parseCore(String? c) => switch (c) {
      'sing-box' => CoreKind.singBox,
      'mihomo' => CoreKind.mihomo,
      _ => null,
    };

String modeWire(ProxyMode m) => switch (m) {
      ProxyMode.tun => 'tun',
      ProxyMode.systemProxy => 'system-proxy',
      ProxyMode.portOnly => 'port',
    };

ProxyMode? parseMode(String? m) => switch (m) {
      'tun' => ProxyMode.tun,
      'system-proxy' => ProxyMode.systemProxy,
      'port' => ProxyMode.portOnly,
      _ => null,
    };
