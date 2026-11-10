import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/backend.dart';
import '../core/panel_api.dart';
import '../core/updater.dart';
import '../models.dart';
import 'settings.dart';
import 'sub_store.dart';

enum NoticeKind { error, info }

class Notice {
  const Notice(this.kind, [this.message = '']);
  final NoticeKind kind;
  final String message;
}

/// Everything the screens render. Talks to the core through [CoreBackend].
class AppState extends ChangeNotifier {
  AppState(this.settings, this.backend, this.store, {this.isDemo = false}) {
    settings.addListener(notifyListeners);
  }

  final Settings settings;
  final CoreBackend backend;
  final SubStore store;
  final bool isDemo;

  final _notices = StreamController<Notice>.broadcast();
  Stream<Notice> get notices => _notices.stream;

  final List<Subscription> subscriptions = [];
  String? activeId;
  bool busySubscriptions = false;

  LinkStatus status = LinkStatus.disconnected;
  CoreStatus coreStatus = const CoreStatus();

  List<ProxyGroup> groups = const [];
  Map<String, ProxyNode> leaves = const {};
  String? groupName; // group shown on the nodes screen
  bool pinging = false;
  int appliedRevision = -1; // settings.coreRevision the running core was started with

  /// Connected with older connection settings: a reconnect would apply them.
  bool get needsReapply => status == LinkStatus.connected && appliedRevision != settings.coreRevision;
  List<ProfileRule> activeRules = const []; // rules of the running core
  String? routingMode; // rule / global / direct, from the core

  // ---- where the traffic comes out ----

  /// Set by main(): looks up the exit IP through the core's proxy port.
  Future<ExitInfo?> Function(int proxyPort, String lang)? exitLookup;
  ExitInfo? exit; // null: unknown (not connected, looking, or failed)
  bool exitLoading = false;
  bool exitFailed = false;
  bool exitRevealed = false; // show the whole IP instead of "1.2.*.*"
  String? _exitNode; // node the current [exit] was looked up for
  Timer? _exitTimer;

  void toggleExitReveal() {
    exitRevealed = !exitRevealed;
    _notify();
  }

  /// Looks the exit up again (after connecting, or when the node in use changed).
  Future<void> refreshExit() async {
    _exitTimer?.cancel();
    final lookup = exitLookup;
    final port = coreStatus.port;
    if (lookup == null || !settings.showExitInfo || status != LinkStatus.connected || port == null) return;
    final forNode = node?.name;
    exitLoading = true;
    exitFailed = false;
    _notify();
    final lang = settings.languageCode ?? (Platform.localeName.toLowerCase().startsWith('ru') ? 'ru' : 'en');
    ExitInfo? info;
    try {
      info = await lookup(port, lang);
    } catch (_) {}
    if (status != LinkStatus.connected) return; // disconnected meanwhile
    exitLoading = false;
    _exitNode = forNode;
    if (info != null) exit = info;
    exitFailed = info == null;
    _notify();
  }

  /// The "show country and IP" setting: look up now, or forget what's shown.
  void setShowExitInfo(bool v) {
    settings.setShowExitInfo(v);
    if (v) {
      unawaited(refreshExit());
    } else {
      _clearExit();
      _notify();
    }
  }

  void _scheduleExit(Duration delay) {
    _exitTimer?.cancel();
    _exitTimer = Timer(delay, refreshExit);
  }

  void _clearExit() {
    _exitTimer?.cancel();
    exit = null;
    exitLoading = exitFailed = false;
    _exitNode = null;
  }

  int upKbps = 0;
  int downKbps = 0;
  /// Live connections, newest first.
  List<ConnectionEntry> connections = const [];
  final Map<String, ConnectionEntry> _active = {};
  /// Connections that were open earlier in this session, newest first.
  final List<ConnectionEntry> closedConnections = [];
  static const _maxClosed = 1000;
  int uploadTotal = 0, downloadTotal = 0;

  /// Core log lines, oldest first.
  final List<LogEntry> logs = [];
  static const _maxLogs = 3000;
  bool logsPaused = false;
  StreamSubscription<LogEntry>? _logSub;
  Timer? _logRetry;
  int? _lastUp, _lastDown;
  DateTime? _lastSample;
  Timer? _trafficTimer;
  Timer? _proxiesTimer;
  bool _disposed = false;
  final Map<String, ProxyNode> _pseudo = {}; // nested groups shown as nodes

  // ---- derived ----

  Subscription? get subscription {
    for (final s in subscriptions) {
      if (s.id == activeId) return s;
    }
    return subscriptions.isEmpty ? null : subscriptions.first;
  }

  /// Modes this platform supports: no system proxy on Android.
  static List<ProxyMode> get availableModes =>
      Platform.isAndroid ? const [ProxyMode.tun, ProxyMode.portOnly] : ProxyMode.values;

  ProxyMode get mode => availableModes.contains(settings.proxyMode) ? settings.proxyMode : ProxyMode.tun;

  /// The core that runs, or would run, the active subscription.
  CoreKind get core {
    if (status == LinkStatus.connected && coreStatus.core != null) return coreStatus.core!;
    return switch (settings.corePref) {
      CorePref.singBox => CoreKind.singBox,
      CorePref.mihomo => CoreKind.mihomo,
      CorePref.auto => subscription?.core ?? CoreKind.singBox,
    };
  }

  bool get coreIsAuto => settings.corePref == CorePref.auto;

  Duration get connectedFor {
    final t = coreStatus.startedAt;
    return (status != LinkStatus.connected || t == null) ? Duration.zero : DateTime.now().difference(t);
  }

  ProxyGroup? get group {
    for (final g in groups) {
      if (g.name == groupName) return g;
    }
    return groups.isEmpty ? null : groups.first;
  }

  ProxyGroup? _groupByName(String name) {
    for (final g in groups) {
      if (g.name == name) return g;
    }
    return null;
  }

  /// Members of the shown group as nodes (nested groups appear as nodes too).
  List<ProxyNode> get groupNodes {
    final g = group;
    if (g == null) return const [];
    return [
      for (final m in g.members)
        leaves[m] ?? _pseudo.putIfAbsent(m, () => ProxyNode(name: m, type: _groupByName(m)?.type ?? '')),
    ];
  }

  /// The server traffic actually goes through: follow group choices to a leaf.
  ProxyNode? get node {
    var g = group;
    for (var i = 0; g != null && i < 8; i++) {
      final now = g.now;
      if (now == null) return null;
      final leaf = leaves[now];
      if (leaf != null) return leaf;
      g = _groupByName(now);
    }
    return null;
  }

  // ---- lifecycle ----

  Future<void> init() async {
    final (list, active) = await store.load();
    subscriptions
      ..clear()
      ..addAll(list);
    activeId = active ?? (list.isEmpty ? null : list.first.id);
    panels
      ..clear()
      ..addAll(await store.loadPanels());
    _notify();
  }

  // ---- SolaHelm panels: sign in, profiles -> subscriptions ----

  /// Set by main(); tests put a fake here.
  PanelApi panelApi = const PanelApi();
  final List<PanelAccount> panels = [];
  bool busyPanels = false;

  Future<void> _savePanels() => store.savePanels(panels);

  /// Signs in to a panel (login + password of the client cabinet) and adds the
  /// client's active profiles as subscriptions. Returns a PanelException code
  /// or null. The password isn't kept: the panel gives an app token.
  Future<String?> loginPanel(String url, String login, String password, {bool selfSigned = false}) async {
    busyPanels = true;
    _notify();
    try {
      final base = PanelApi.normalizeUrl(url);
      final r = await panelApi.login(base, login.trim(), password, selfSigned: selfSigned);
      final who = r.clientLogin.isEmpty ? login.trim() : r.clientLogin;
      var acc = panels.where((p) => p.url == base && p.login == who).firstOrNull;
      if (acc == null) {
        acc = PanelAccount(
          id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
          url: base,
          login: who,
          token: r.token!,
          insecure: selfSigned,
        );
        panels.add(acc);
      } else {
        acc
          ..token = r.token!
          ..insecure = selfSigned;
      }
      _takeReply(acc, r);
      await _savePanels();
      await _applyPanel(acc);
      return null;
    } on PanelException catch (e) {
      return e.code;
    } catch (e) {
      return e.toString();
    } finally {
      busyPanels = false;
      _notify();
    }
  }

  /// Fetches the profiles again: new active profiles become subscriptions,
  /// a changed subscription link is followed. Returns a PanelException code or null.
  Future<String?> syncPanel(String id, {bool quiet = false}) async {
    final acc = panels.where((p) => p.id == id).firstOrNull;
    if (acc == null) return 'not found';
    if (acc.needsLogin) return 'unauthorized';
    if (!quiet) {
      busyPanels = true;
      _notify();
    }
    try {
      _takeReply(acc, await panelApi.profiles(acc.url, acc.token, selfSigned: acc.insecure));
      await _savePanels();
      await _applyPanel(acc, quiet: quiet);
      return null;
    } on PanelException catch (e) {
      if (e.code == 'unauthorized') {
        acc.needsLogin = true; // revoked in the cabinet, password changed, or the client disabled
        await _savePanels();
      }
      return e.code;
    } finally {
      busyPanels = false;
      _notify();
    }
  }

  /// Quietly syncs every panel (at start).
  Future<void> syncPanels() async {
    for (final p in List.of(panels)) {
      try {
        await syncPanel(p.id, quiet: true);
      } catch (_) {}
    }
  }

  /// Signs out: the token is revoked in the panel (best effort) and forgotten.
  /// The subscriptions stay, unless [removeSubscriptions].
  Future<void> logoutPanel(String id, {bool removeSubscriptions = false}) async {
    final acc = panels.where((p) => p.id == id).firstOrNull;
    if (acc == null) return;
    try {
      if (!acc.needsLogin) await panelApi.logout(acc.url, acc.token, selfSigned: acc.insecure);
    } catch (_) {}
    panels.remove(acc);
    await _savePanels();
    for (final s in subscriptions.where((s) => s.panelId == id).toList()) {
      if (removeSubscriptions) {
        await removeSubscription(s.id);
      } else {
        final i = subscriptions.indexOf(s);
        subscriptions[i] = s.copyWith(panelId: () => null, panelProfileId: () => null);
      }
    }
    await _persist();
    _notify();
  }

  void _takeReply(PanelAccount acc, PanelReply r) {
    acc
      ..panelName = r.panelName
      ..panelVersion = r.panelVersion
      ..clientName = r.clientName
      ..profiles = r.profiles
      ..syncedAt = DateTime.now()
      ..needsLogin = false;
  }

  /// Active profiles -> subscriptions (added once, then kept in step).
  Future<void> _applyPanel(PanelAccount acc, {bool quiet = false}) async {
    for (final p in acc.profiles.where((p) => p.active)) {
      final url = p.subscriptionUrl!;
      var i = subscriptions.indexWhere((s) => s.panelId == acc.id && s.panelProfileId == p.id);
      if (i < 0) i = subscriptions.indexWhere((s) => s.url == url); // added by hand before
      if (i >= 0) {
        final s = subscriptions[i];
        final moved = s.url != url; // the panel re-issued the subscription link
        subscriptions[i] = s.copyWith(
            url: url, panelId: () => acc.id, panelProfileId: () => p.id, insecure: acc.insecure);
        if (moved) await refreshSubscription(s.id);
        continue;
      }
      final (err, _) = await _addSubscription(url, panelId: acc.id, panelProfileId: p.id, insecure: acc.insecure);
      if (err != null && !quiet) _error(CoreException('${p.name}: $err'));
    }
    await _persist();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _error(Object e) => _notices.add(Notice(NoticeKind.error, e.toString()));

  // ---- subscriptions ----

  /// Downloads and stores a subscription. Returns an error message or null.
  Future<String?> addSubscription(String url) async => (await _addSubscription(url)).$1;

  /// (error, id of the new subscription).
  Future<(String?, String?)> _addSubscription(String url,
      {String? panelId, int? panelProfileId, bool insecure = false}) async {
    busySubscriptions = true;
    _notify();
    try {
      final r = await backend.fetch(url, insecure: insecure);
      if (r.format == null) return (r.error ?? 'Unknown subscription format', null);
      final id = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
      final host = Uri.tryParse(url)?.host ?? url;
      final sub = _fromFetch(id, (r.title?.isNotEmpty ?? false) ? r.title! : host, url, r)
          .copyWith(panelId: () => panelId, panelProfileId: () => panelProfileId, insecure: insecure);
      await store.saveContent(id, r.content);
      subscriptions.add(sub);
      activeId ??= id;
      await _persist();
      return (null, id);
    } catch (e) {
      return (e.toString(), null);
    } finally {
      busySubscriptions = false;
      _notify();
    }
  }

  Subscription _fromFetch(String id, String name, String url, FetchResult r) => Subscription(
        id: id,
        name: name,
        url: url,
        format: r.format,
        core: r.core,
        protocols: r.protocols,
        linkCount: r.linkCount,
        unsupported: r.unsupported,
        upload: r.upload,
        download: r.download,
        total: r.total,
        expire: r.expire,
        updatedAt: DateTime.now(),
      );

  Future<void> refreshSubscription(String id) async {
    final i = subscriptions.indexWhere((s) => s.id == id);
    if (i < 0) return;
    final old = subscriptions[i];
    busySubscriptions = true;
    _notify();
    try {
      if (old.source == SubSource.pasted) return;
      if (old.source == SubSource.file) {
        final text = await File(old.url).readAsString();
        final v = await backend.validate(text);
        if (!v.ok) throw CoreException(v.error ?? 'Unknown format');
        await store.saveContent(id, text);
        subscriptions[i] = old.copyWith(
          format: v.format,
          core: v.core,
          protocols: v.protocols,
          linkCount: v.linkCount,
          unsupported: v.unsupported,
          updatedAt: DateTime.now(),
          edited: false,
        );
      } else {
        final r = await backend.fetch(old.url, insecure: old.insecure);
        if (r.format == null) throw CoreException(r.error ?? 'Unknown subscription format');
        await store.saveContent(id, r.content);
        final fresh = _fromFetch(id, old.name, old.url, r);
        subscriptions[i] = fresh.copyWith(
          rules: () => old.rules,
          rulesReplace: old.rulesReplace,
          panelId: () => old.panelId,
          panelProfileId: () => old.panelProfileId,
          insecure: old.insecure,
        );
      }
      await _persist();
      if (id == activeId && status == LinkStatus.connected) await reconnect();
    } catch (e) {
      _error(e);
    } finally {
      busySubscriptions = false;
      _notify();
    }
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  /// Imports a config file. Returns an error message or null.
  Future<String?> importFile(String path) async {
    try {
      final text = await File(path).readAsString();
      final name = path.split(RegExp(r'[\\/]')).last;
      return await _importText(text, name: name, source: SubSource.file, url: path);
    } catch (e) {
      return e.toString();
    }
  }

  /// Imports config text (from the clipboard). Returns an error message or null.
  Future<String?> importText(String text, {required String name}) =>
      _importText(text, name: name, source: SubSource.pasted, url: '');

  Future<String?> _importText(String text,
      {required String name, required SubSource source, required String url}) async {
    busySubscriptions = true;
    _notify();
    try {
      final v = await backend.validate(text);
      if (!v.ok) return v.error ?? 'Unknown format';
      final id = _newId();
      await store.saveContent(id, text);
      subscriptions.add(Subscription(
        id: id,
        name: name,
        url: url,
        format: v.format,
        core: v.core,
        protocols: v.protocols,
        linkCount: v.linkCount,
        unsupported: v.unsupported,
        updatedAt: DateTime.now(),
        source: source,
      ));
      activeId ??= id;
      await _persist();
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      busySubscriptions = false;
      _notify();
    }
  }

  Future<String?> profileContent(String id) => store.content(id);

  /// Saves an edited profile body after checking it. Returns an error or null.
  Future<String?> saveProfileContent(String id, String text) async {
    final i = subscriptions.indexWhere((s) => s.id == id);
    if (i < 0) return 'not found';
    final v = await backend.validate(text);
    if (!v.ok) return v.error ?? 'Unknown format';
    await store.saveContent(id, text);
    final old = subscriptions[i];
    subscriptions[i] = old.copyWith(
      format: v.format,
      core: v.core,
      protocols: v.protocols,
      linkCount: v.linkCount,
      unsupported: v.unsupported,
      edited: old.source == SubSource.remote,
      updatedAt: DateTime.now(),
    );
    await _persist();
    _notify();
    if (id == activeId && status == LinkStatus.connected) await reconnect();
    return null;
  }

  Future<void> renameSubscription(String id, String name) async {
    final i = subscriptions.indexWhere((s) => s.id == id);
    if (i < 0 || name.trim().isEmpty) return;
    subscriptions[i] = subscriptions[i].copyWith(name: name.trim());
    await _persist();
    _notify();
  }

  /// Rules of a profile for the editor.
  Future<ProfileRulesInfo> profileRules(String id) async {
    final text = await store.content(id);
    if (text == null) throw CoreException('The subscription has not been downloaded');
    return backend.profileRules(text, routing: settings.core.linkRouting);
  }

  /// Saves user rules for a profile after the core accepts them.
  /// [lines] == null drops the user rules. Returns an error or null.
  Future<String?> saveRules(String id, List<String>? lines, {required bool replace}) async {
    final i = subscriptions.indexWhere((s) => s.id == id);
    if (i < 0) return 'not found';
    final text = await store.content(id);
    if (text == null) return 'The subscription has not been downloaded';
    if (lines != null) {
      final v = await backend.validate(text, rules: lines, rulesReplace: replace, routing: settings.core.linkRouting);
      if (!v.ok) return v.error ?? 'invalid rules';
    }
    subscriptions[i] = subscriptions[i].copyWith(rules: () => lines, rulesReplace: replace);
    await _persist();
    _notify();
    if (id == activeId && status == LinkStatus.connected) await reconnect();
    return null;
  }

  Future<void> removeSubscription(String id) async {
    subscriptions.removeWhere((s) => s.id == id);
    await store.delete(id);
    if (activeId == id) {
      activeId = subscriptions.isEmpty ? null : subscriptions.first.id;
      if (status != LinkStatus.disconnected) await disconnect();
    }
    await _persist();
    _notify();
  }

  Future<void> selectSubscription(String id) async {
    if (activeId == id) return;
    activeId = id;
    await _persist();
    _notify();
    if (status == LinkStatus.connected) await reconnect();
  }

  Future<void> _persist() => store.save(subscriptions, activeId);

  // ---- connection ----

  /// Ignored while a connect or disconnect is in progress.
  Future<void> toggleConnection() async {
    if (status.busy) return;
    if (status == LinkStatus.disconnected) {
      await connect();
    } else {
      await disconnect();
    }
  }

  /// Connects the active subscription. TUN without admin rights restarts the
  /// core elevated right away (one UAC prompt, or none if the app itself runs
  /// as administrator); if that is refused, an error explains why.
  Future<void> connect({bool allowElevate = true}) async {
    final sub = subscription;
    if (sub == null) {
      _notices.add(const Notice(NoticeKind.info, 'no-subscription'));
      return;
    }
    status = LinkStatus.connecting;
    _notify();
    try {
      final content = await store.content(sub.id);
      if (content == null) throw CoreException('The subscription has not been downloaded');
      final cs = settings.core;
      final revision = settings.coreRevision;
      coreStatus = await backend.start(
        content: content,
        core: settings.corePref,
        mode: mode,
        port: cs.mixedPort,
        rules: sub.rules,
        rulesReplace: sub.rulesReplace,
        tuning: cs.tuning(),
        bypass: cs.proxyBypass,
        findProcess: cs.findProcess && !Platform.isAndroid, // Android hides other apps' sockets
        tunStack: cs.manageTun ? cs.tunStack : 'gvisor', // gvisor: no firewall prompt
        routing: cs.linkRouting,
      );
      appliedRevision = revision;
      await _onConnected();
    } on CoreException catch (e) {
      status = LinkStatus.disconnected;
      if (e.needsElevation && allowElevate) {
        try {
          await backend.elevate();
        } catch (_) {
          _notices.add(const Notice(NoticeKind.error, notElevated));
          _notify();
          return;
        }
        await connect(allowElevate: false);
        return;
      }
      _notices.add(Notice(NoticeKind.error, e.needsElevation ? notElevated : e.message));
    } catch (e) {
      status = LinkStatus.disconnected;
      _error(e);
    }
    _notify();
  }

  Future<void> _onConnected() async {
    status = LinkStatus.connected;
    _lastUp = _lastDown = null;
    await _loadProxies();
    _trafficTimer?.cancel();
    _proxiesTimer?.cancel();
    _trafficTimer = Timer.periodic(const Duration(seconds: 1), (_) => _sampleTraffic());
    _listenLogs();
    _proxiesTimer = Timer.periodic(const Duration(seconds: 10), (_) => _loadProxies());
    _clearExit();
    _scheduleExit(const Duration(milliseconds: 800)); // let the first connections settle
  }

  /// Takes over a core left running by "exit, keep the core".
  Future<void> attachRunningCore() async {
    try {
      final st = await backend.attachExisting();
      if (st == null || !st.running) return;
      coreStatus = st;
      appliedRevision = settings.coreRevision;
      await _onConnected();
      _notify();
    } catch (_) {}
  }

  /// The VPN was turned on or off outside the UI (Android tile or
  /// notification): show what the core is actually doing.
  Future<void> syncWithCore() async {
    if (status == LinkStatus.connecting || status == LinkStatus.disconnecting) return;
    final st = await backend.attachExisting();
    if (st != null && st.running) {
      if (status == LinkStatus.connected) return;
      coreStatus = st;
      appliedRevision = settings.coreRevision;
      await _onConnected();
      _notify();
    } else if (status == LinkStatus.connected) {
      await disconnect(); // the core is already stopped; this resets the UI
    }
  }

  /// Exits the app but leaves the core (and the VPN) running.
  Future<void> detachForExit() async {
    _trafficTimer?.cancel();
    _proxiesTimer?.cancel();
    _logRetry?.cancel();
    unawaited(_logSub?.cancel());
    await backend.detachForExit();
  }

  // ---- updates ----

  /// Set by main(); null in tests or when updates aren't supported.
  Updater? updater;
  UpdateInfo? update; // a newer release, when found
  bool checkingUpdate = false;
  double? updateProgress; // 0..1 while downloading
  String? updateStatus; // last check result: 'latest', 'none' or an error

  int? get _proxyPort => status == LinkStatus.connected ? coreStatus.port : null;

  Future<void> checkForUpdates({bool silent = false}) async {
    final u = updater;
    if (u == null || checkingUpdate) return;
    checkingUpdate = true;
    _notify();
    try {
      update = await u.check(proxyPort: _proxyPort);
      updateStatus = update == null ? (u.lastHadRelease ? 'latest' : 'none') : null;
      if (update != null && silent) _notices.add(Notice(NoticeKind.info, 'update:${update!.version}'));
    } catch (e) {
      updateStatus = e.toString();
    } finally {
      checkingUpdate = false;
      _notify();
    }
  }

  /// Downloads the update and starts the installer; returns true when the app
  /// should now exit so the installer can replace its files.
  Future<bool> downloadAndInstallUpdate() async {
    final u = updater, info = update;
    if (u == null || info == null || updateProgress != null) return false;
    updateProgress = 0;
    _notify();
    try {
      final zip = await u.download(info, proxyPort: _proxyPort, onProgress: (p) {
        updateProgress = p;
        _notify();
      });
      await u.install(zip, reconnect: status == LinkStatus.connected);
      return true;
    } catch (e) {
      updateStatus = e.toString();
      _error(e);
      return false;
    } finally {
      updateProgress = null;
      _notify();
    }
  }

  /// Notice message key: TUN needs admin rights and they were not granted.
  static const notElevated = 'not-elevated';

  Future<void> disconnect() async {
    _clearExit();
    status = LinkStatus.disconnecting;
    _notify();
    _trafficTimer?.cancel();
    _proxiesTimer?.cancel();
    _trafficTimer = _proxiesTimer = null;
    _logRetry?.cancel();
    unawaited(_logSub?.cancel()); // never wait on the log stream: it must not block disconnect
    _logSub = null;
    final now = DateTime.now();
    for (final c in _active.values) {
      c
        ..closedAt = now
        ..upSpeed = 0
        ..downSpeed = 0;
      closedConnections.insert(0, c);
    }
    _active.clear();
    _trimClosed();
    try {
      coreStatus = await backend.stop().timeout(const Duration(seconds: 15));
    } on TimeoutException {
      _error(CoreException('The core did not stop in time; use Restart in the tray menu'));
    } catch (e) {
      _error(e);
    }
    status = LinkStatus.disconnected;
    groups = const [];
    leaves = const {};
    activeRules = const [];
    connections = const [];
    upKbps = downKbps = 0;
    _notify();
  }

  Future<void> reconnect() async {
    await disconnect();
    await connect();
  }

  Future<void> setMode(ProxyMode m) async {
    if (m == mode) return;
    settings.setProxyMode(m);
    if (status == LinkStatus.connected) await reconnect();
  }

  Future<void> _loadProxies() async {
    try {
      final snap = await backend.proxies();
      // Keep measured delays across refreshes.
      for (final e in snap.leaves.entries) {
        final old = leaves[e.key];
        if (old != null && e.value.delayMs == null) {
          e.value
            ..delayMs = old.delayMs
            ..timedOut = old.timedOut;
        }
      }
      try {
        activeRules = await backend.activeRules();
      } catch (_) {}
      groups = snap.groups;
      leaves = snap.leaves;
      try {
        routingMode = await backend.routingMode();
      } catch (_) {}
      if (groupName == null || _groupByName(groupName!) == null) {
        groupName = groups.isEmpty ? null : groups.first.name;
      }
      // The traffic now leaves through another server (manual pick or "Auto"): look again.
      if (status == LinkStatus.connected && !exitLoading && _exitNode != null && node?.name != _exitNode) {
        _scheduleExit(const Duration(milliseconds: 300));
      }
      _notify();
    } catch (_) {
      // Transient: the next tick retries.
    }
  }

  /// Polls the core once (the 1 s timer calls this too).
  Future<void> refreshTraffic() => _sampleTraffic();

  Future<void> _sampleTraffic() async {
    try {
      final t = await backend.traffic();
      final now = DateTime.now();
      if (_lastUp != null && _lastSample != null) {
        final secs = now.difference(_lastSample!).inMilliseconds / 1000;
        if (secs > 0) {
          upKbps = ((t.uploadTotal - _lastUp!).clamp(0, 1 << 62) / 1024 / secs).round();
          downKbps = ((t.downloadTotal - _lastDown!).clamp(0, 1 << 62) / 1024 / secs).round();
        }
      }
      _lastUp = t.uploadTotal;
      _lastDown = t.downloadTotal;
      _lastSample = now;
      _trackConnections(t.connections, now);
      uploadTotal = t.uploadTotal;
      downloadTotal = t.downloadTotal;
      _notify();
    } catch (_) {}
  }

  void _trackConnections(List<ConnectionEntry> fresh, DateTime now) {
    final secs = _lastConnSample == null ? 0.0 : now.difference(_lastConnSample!).inMilliseconds / 1000;
    final seen = <String>{};
    for (final c in fresh) {
      seen.add(c.id);
      final old = _active[c.id];
      if (old != null && secs > 0) {
        c.upSpeed = ((c.upload - old.upload).clamp(0, 1 << 62) / secs).round();
        c.downSpeed = ((c.download - old.download).clamp(0, 1 << 62) / secs).round();
      }
      _active[c.id] = c;
    }
    final gone = _active.keys.where((id) => !seen.contains(id)).toList();
    for (final id in gone) {
      final c = _active.remove(id)!
        ..closedAt = now
        ..upSpeed = 0
        ..downSpeed = 0;
      closedConnections.insert(0, c);
    }
    _trimClosed();
    _lastConnSample = now;
    connections = _active.values.toList()
      ..sort((a, b) => (b.start ?? now).compareTo(a.start ?? now));
  }

  DateTime? _lastConnSample;

  void _trimClosed() {
    if (closedConnections.length > _maxClosed) closedConnections.removeRange(_maxClosed, closedConnections.length);
  }

  Future<void> closeConnection(String id) async {
    try {
      await backend.closeConnection(id);
      await _sampleTraffic();
    } catch (e) {
      _error(e);
    }
  }

  Future<void> closeAllConnections() async {
    try {
      await backend.closeAllConnections();
      await _sampleTraffic();
    } catch (e) {
      _error(e);
    }
  }

  void clearClosedConnections() {
    closedConnections.clear();
    _notify();
  }

  void _listenLogs() {
    _logSub?.cancel();
    _logSub = backend.logs().listen((e) {
      if (logsPaused) return;
      logs.add(e);
      if (logs.length > _maxLogs) logs.removeRange(0, logs.length - _maxLogs);
      _notify();
    }, onDone: () {
      // The stream drops when the core restarts; reattach while connected.
      if (status == LinkStatus.connected && !_disposed) {
        _logRetry?.cancel();
        _logRetry = Timer(const Duration(seconds: 2), () {
          if (status == LinkStatus.connected && !_disposed) _listenLogs();
        });
      }
    }, onError: (_) {});
  }

  void setLogsPaused(bool v) {
    logsPaused = v;
    _notify();
  }

  void clearLogs() {
    logs.clear();
    _notify();
  }

  Future<void> setRoutingMode(String mode) async {
    try {
      await backend.setRoutingMode(mode);
      routingMode = mode;
      await closeAllConnections(); // so open connections follow the new mode
      _notify();
    } catch (e) {
      _error(e);
    }
  }

  /// Picks [node] in [groupName] (tray menu); [groupName] must be a selector.
  Future<void> selectNodeIn(String groupName, String node) async {
    try {
      await backend.select(groupName, node);
      await _loadProxies();
    } catch (e) {
      _error(e);
    }
  }

  ProxyGroup? groupByName(String name) => _groupByName(name);

  void showGroup(String name) {
    groupName = name;
    _notify();
  }

  Future<void> selectNode(String name) async {
    final g = group;
    if (g == null || !g.selectable) return;
    try {
      await backend.select(g.name, name);
      await _loadProxies();
    } catch (e) {
      _error(e);
    }
  }

  /// Measures every member of the shown group in parallel.
  Future<void> pingAll() async {
    final nodes = groupNodes;
    if (nodes.isEmpty || pinging) return;
    pinging = true;
    for (final n in nodes) {
      n.measuring = true;
    }
    _notify();
    await Future.wait(nodes.map((n) async {
      final d = await backend.delay(n.name);
      n
        ..measuring = false
        ..delayMs = d
        ..timedOut = d == null;
      final leaf = leaves[n.name];
      if (leaf != null && !identical(leaf, n)) {
        leaf
          ..delayMs = d
          ..timedOut = d == null;
      }
      _notify();
    }));
    pinging = false;
    await _loadProxies();
  }

  @override
  void dispose() {
    _disposed = true;
    _exitTimer?.cancel();
    _trafficTimer?.cancel();
    _proxiesTimer?.cancel();
    _logSub?.cancel();
    _logRetry?.cancel();
    settings.removeListener(notifyListeners);
    _notices.close();
    backend.dispose();
    super.dispose();
  }
}
