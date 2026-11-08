// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class SEn extends S {
  SEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'SolaHelm';

  @override
  String get navHome => 'Home';

  @override
  String get navNodes => 'Nodes';

  @override
  String get navSubscriptions => 'Subscriptions';

  @override
  String get navConnections => 'Connections';

  @override
  String get navLogs => 'Logs';

  @override
  String get navSettings => 'Settings';

  @override
  String get statusDisconnected => 'Disconnected';

  @override
  String get statusConnected => 'Connected';

  @override
  String get statusConnecting => 'Connecting…';

  @override
  String get tapToConnect => 'Tap to connect';

  @override
  String get connect => 'Connect';

  @override
  String get disconnect => 'Disconnect';

  @override
  String connectedFor(String time, String core) {
    return '$time · $core core';
  }

  @override
  String coreAutoChip(String core) {
    return '$core · auto';
  }

  @override
  String coreChosenAuto(String core) {
    return '$core core picked automatically';
  }

  @override
  String coreChosenManual(String core) {
    return '$core core pinned in settings';
  }

  @override
  String get modeLabel => 'Mode';

  @override
  String get modeTun => 'TUN';

  @override
  String get modeSystemProxy => 'System proxy';

  @override
  String modePortOnly(int port) {
    return 'Port $port only';
  }

  @override
  String get metricNode => 'Node';

  @override
  String get metricLatency => 'Latency';

  @override
  String get metricSpeed => 'Speed';

  @override
  String get metricTraffic => 'Traffic';

  @override
  String kbps(int value) {
    return '$value KB/s';
  }

  @override
  String gb(String value) {
    return '$value GB';
  }

  @override
  String trafficOf(String used, String total) {
    return '$used of $total';
  }

  @override
  String groupLabel(String name) {
    return 'Group: $name';
  }

  @override
  String get groupAuto => 'Auto (fastest)';

  @override
  String get ping => 'Ping';

  @override
  String pingMs(int ms) {
    return '$ms ms';
  }

  @override
  String get pingTimeout => 'timeout';

  @override
  String get pingUnknown => '—';

  @override
  String get recentConnections => 'Recent connections';

  @override
  String get routeDirect => 'direct';

  @override
  String routeVia(String node) {
    return 'VPN · $node';
  }

  @override
  String get addSubscription => 'Add subscription';

  @override
  String get subscriptionUrl => 'Subscription link';

  @override
  String get subscriptionUrlHint => 'https://panel.example.org/…/sub/…';

  @override
  String get add => 'Add';

  @override
  String get cancel => 'Cancel';

  @override
  String get errorUrlEmpty => 'Enter a link';

  @override
  String get errorUrlInvalid => 'The link must start with http:// or https://';

  @override
  String get scanQr => 'QR code';

  @override
  String get pasteClipboard => 'Paste';

  @override
  String get clipboardEmpty => 'No link in the clipboard';

  @override
  String get subPending => 'Loads once the core is connected';

  @override
  String expiresOn(String date) {
    return 'until $date';
  }

  @override
  String get noExpiry => 'no expiry';

  @override
  String get unlimited => 'unlimited';

  @override
  String get formatSingBox => 'sing-box JSON';

  @override
  String get formatClash => 'Clash YAML';

  @override
  String formatLinks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count links',
      one: '$count link',
    );
    return '$_temp0';
  }

  @override
  String reasonOnlyIn(String protocol, String core) {
    return '$protocol is only in $core';
  }

  @override
  String get reasonByFormat => 'core picked by format';

  @override
  String rulesTemplate(String name) {
    return '“$name” rules';
  }

  @override
  String get settingsTheme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get settingsCore => 'Core';

  @override
  String get coreAuto => 'Auto';

  @override
  String get coreHint =>
      'In Auto mode the core is picked from the subscription format and protocols. If a protocol exists in only one core, that core is used.';

  @override
  String get settingsAbout => 'About';

  @override
  String coreVersions(String sb, String mh) {
    return 'sing-box $sb · mihomo $mh';
  }

  @override
  String get demoBanner => 'Demo data: the UI isn\'t connected to the core yet';

  @override
  String get comingSoon =>
      'This section arrives once the UI is connected to the core.';

  @override
  String get nodesNotConnected => 'Connect to see the subscription\'s nodes.';

  @override
  String get groupAutoHint => 'This group picks a node by itself, by latency.';

  @override
  String get noSubscriptions =>
      'Add a subscription: the link from your panel\'s cabinet.';

  @override
  String get noSubscriptionsTitle => 'No subscriptions yet';

  @override
  String get needSubscription => 'Add a subscription first';

  @override
  String get refresh => 'Refresh';

  @override
  String get delete => 'Delete';

  @override
  String get subscriptionAdded => 'Subscription added';

  @override
  String updatedAt(String time) {
    return 'updated $time';
  }

  @override
  String localPort(int port) {
    return 'Port 127.0.0.1:$port';
  }

  @override
  String get adminBadge => 'admin';

  @override
  String get coreMissing =>
      'solahelm-core wasn\'t found next to the app; showing demo data';

  @override
  String errorPrefix(String message) {
    return 'Error: $message';
  }

  @override
  String get noConnections => 'No connections yet.';

  @override
  String get connectionsHint =>
      'Live connections through the core: where they go and via which node.';

  @override
  String trafficUnlimited(String used) {
    return '$used · unlimited';
  }

  @override
  String get groupSelector => 'manual choice';

  @override
  String get groupUrlTest => 'auto, by latency';

  @override
  String get groupFallback => 'fallback: first working';

  @override
  String get groupLoadBalance => 'load balancing';

  @override
  String get logsEmpty =>
      'The log is empty. Core lines appear once you connect.';

  @override
  String get search => 'Search';

  @override
  String get pause => 'Pause';

  @override
  String get resume => 'Resume';

  @override
  String get clear => 'Clear';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get levelAll => 'All';

  @override
  String get connActive => 'Active';

  @override
  String get connClosed => 'Closed';

  @override
  String processesCount(int n) {
    return 'Processes: $n';
  }

  @override
  String get filter => 'Filter';

  @override
  String get sortDownload => 'Downloaded';

  @override
  String get sortUpload => 'Uploaded';

  @override
  String get sortTime => 'Time';

  @override
  String get sortHost => 'Host';

  @override
  String get sortCount => 'Connections';

  @override
  String get byProcess => 'By process';

  @override
  String get flatList => 'As a list';

  @override
  String get closeAll => 'Close all';

  @override
  String get closeConnection => 'Close connection';

  @override
  String get back => 'Back';

  @override
  String secondsAgo(int n) {
    return '$n s ago';
  }

  @override
  String minutesAgo(int n) {
    return '$n min ago';
  }

  @override
  String hoursAgo(int n) {
    return '$n h ago';
  }

  @override
  String get secTraffic => 'Traffic';

  @override
  String get upSpeed => 'Upload speed';

  @override
  String get downSpeed => 'Download speed';

  @override
  String get uploaded => 'Uploaded';

  @override
  String get downloaded => 'Downloaded';

  @override
  String get secRouting => 'Routing';

  @override
  String get rule => 'Rule';

  @override
  String get chain => 'Proxy chain';

  @override
  String get connType => 'Connection type';

  @override
  String get secNetwork => 'Network';

  @override
  String get host => 'Host';

  @override
  String get destIp => 'Destination IP';

  @override
  String get srcIp => 'Source IP';

  @override
  String get srcPort => 'Source port';

  @override
  String get destPort => 'Destination port';

  @override
  String get remote => 'Remote destination';

  @override
  String get secProcess => 'Process';

  @override
  String get processName => 'Name';

  @override
  String get processPath => 'Path';

  @override
  String get started => 'Started';

  @override
  String get close => 'Close';

  @override
  String get statusActive => 'Active';

  @override
  String get statusClosed => 'Closed';

  @override
  String get clearClosed => 'Clear closed';

  @override
  String get settingsBehavior => 'Behavior';

  @override
  String get closeToTray => 'Minimize to tray when the window is closed';

  @override
  String get launchAtStartup => 'Start with Windows';

  @override
  String get startMinimized => 'Start minimized to tray';

  @override
  String get autoConnect => 'Connect on start';

  @override
  String get autoConnectTunNote =>
      'In TUN mode Windows will ask for administrator rights when connecting on start.';

  @override
  String get trayShow => 'Open SolaHelm';

  @override
  String get trayExit => 'Exit';

  @override
  String trayModeMenu(String mode) {
    return 'Connection mode ($mode)';
  }

  @override
  String routingMenu(String mode) {
    return 'Routing ($mode)';
  }

  @override
  String get routingRule => 'Rules';

  @override
  String get routingGlobal => 'Global';

  @override
  String get routingDirect => 'Direct';

  @override
  String get routingLabel => 'Routing';

  @override
  String get notElevated =>
      'Not enough rights for TUN: Windows did not allow the core to run as administrator. Accept the prompt or switch to System proxy.';
}
