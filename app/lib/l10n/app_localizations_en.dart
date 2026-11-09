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
  String linksSkipped(String protocols) {
    return 'skipped: $protocols';
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

  @override
  String get navRules => 'Rules';

  @override
  String get importFile => 'File';

  @override
  String pastedName(String date) {
    return 'From clipboard $date';
  }

  @override
  String get profileAdded => 'Profile added';

  @override
  String get menuOpen => 'Open and edit';

  @override
  String get menuRules => 'Rules';

  @override
  String get rename => 'Rename';

  @override
  String get nameLabel => 'Name';

  @override
  String get sourceFile => 'file';

  @override
  String get sourcePasted => 'pasted';

  @override
  String get editedBadge => 'edited';

  @override
  String get rulesBadge => 'own rules';

  @override
  String get check => 'Check';

  @override
  String get save => 'Save';

  @override
  String get saved => 'Saved';

  @override
  String checkOk(String format, String core) {
    return 'Config is fine: $format, $core core';
  }

  @override
  String checkOkLinks(int n) {
    return 'Links are fine: $n proxies, mihomo core';
  }

  @override
  String get editedWarning =>
      'This profile comes from a link: a subscription refresh replaces edits to its text. Put your own rules in Rules, they are kept separately.';

  @override
  String get unsavedTitle => 'Unsaved changes';

  @override
  String get discard => 'Discard';

  @override
  String get rulesEdit => 'Edit';

  @override
  String get rulesActive => 'Active rules';

  @override
  String get rulesOfProfile => 'Profile rules';

  @override
  String get rulesNone => 'No rules';

  @override
  String rulesCount(int n) {
    return 'Rules: $n';
  }

  @override
  String get ruleType => 'Rule type';

  @override
  String get rulePayload => 'Value';

  @override
  String get ruleTarget => 'Proxy';

  @override
  String get addTop => 'To top';

  @override
  String get addBottom => 'To bottom';

  @override
  String get asText => 'As text';

  @override
  String get asList => 'As list';

  @override
  String get rulesHintReplace =>
      'This list replaces the profile\'s rules and is kept apart from the subscription: a refresh won\'t reset it.';

  @override
  String get rulesHintPrepend =>
      'sing-box profile: your rules go in front of the profile\'s rules. The profile\'s own rules are below, read-only.';

  @override
  String get resetRules => 'Restore profile rules';

  @override
  String get profileRulesReadonly => 'Profile rules (read-only)';

  @override
  String get searchRules => 'Search rules';

  @override
  String ruleInvalid(int n, String line) {
    return 'Bad rule on line $n: $line';
  }

  @override
  String get rulesSaved => 'Rules saved';

  @override
  String get payloadEmpty => 'Enter a value';

  @override
  String get addRuleFor => 'Rule';

  @override
  String get ruleDirect => 'Direct';

  @override
  String get ruleProxy => 'Via VPN';

  @override
  String get ruleReject => 'Block';

  @override
  String ruleAddedFor(String what) {
    return 'Rule for $what added';
  }

  @override
  String rulesEditorTitle(String name) {
    return 'Rules: $name';
  }

  @override
  String get rulesNotConnectedHint =>
      'Showing the profile\'s rules. Connect to see the rules the core applied.';

  @override
  String get formatLinksShort => 'Share links';

  @override
  String get statusDisconnecting => 'Disconnecting…';

  @override
  String get trayRestart => 'Restart';

  @override
  String get settingsConnection => 'Connection and TUN';

  @override
  String get settingsConnectionHint =>
      'TUN stack and routes, system proxy exceptions, ports, LAN access';

  @override
  String get settingsCoreAdv => 'Core';

  @override
  String get settingsCoreAdvHint =>
      'IPv6, log level, process detection, core versions';

  @override
  String get reapplyHint => 'Changes apply after reconnecting.';

  @override
  String get reapply => 'Reconnect';

  @override
  String get secTun => 'TUN';

  @override
  String get manageTun => 'Manage TUN settings';

  @override
  String get manageTunOff =>
      'The profile\'s settings are used (gVisor stack, no firewall prompts).';

  @override
  String get tunStack => 'Stack';

  @override
  String get tunStackHint =>
      'gVisor opens no ports and causes no firewall prompt. Mixed and System are faster, but Windows may ask for permission.';

  @override
  String get strictRoute => 'Strict routing';

  @override
  String get strictRouteHint =>
      'Keeps DNS queries from leaking around the tunnel.';

  @override
  String get mtu => 'MTU';

  @override
  String get routeExclude => 'Networks excluded from TUN';

  @override
  String get routeExcludeHint =>
      'These networks go direct, around the tunnel: LAN, RDP, printers.';

  @override
  String get addNetwork => 'Add network';

  @override
  String get networkHint => '192.168.1.0/24';

  @override
  String get secSysProxy => 'System proxy';

  @override
  String get proxyBypass => 'System proxy exceptions';

  @override
  String get proxyBypassHint =>
      'Addresses apps reach directly. Masks work: 192.168.*, *.local, <local>.';

  @override
  String get addException => 'Add exception';

  @override
  String get restoreDefaults => 'Default list';

  @override
  String get secPorts => 'Ports';

  @override
  String get mixedPort => 'Mixed port (HTTP + SOCKS)';

  @override
  String get mixedPortHint => 'If the port is busy, the next free one is used.';

  @override
  String get allowLan => 'Allow connections from the LAN';

  @override
  String get allowLanHint =>
      'Other devices can use this computer\'s proxy. Windows may ask for a firewall permission.';

  @override
  String lanAddresses(String list) {
    return 'Addresses for other devices: $list';
  }

  @override
  String get ipv6 => 'IPv6';

  @override
  String get ipv6Profile => 'From profile';

  @override
  String get ipv6On => 'On';

  @override
  String get ipv6Off => 'Off';

  @override
  String get logLevel => 'Log level';

  @override
  String get logLevelProfile => 'From profile';

  @override
  String get findProcess => 'Detect processes';

  @override
  String get findProcessHint =>
      'Needed to group connections and for PROCESS-NAME rules. Turn off to save some CPU.';

  @override
  String get coresBuiltIn =>
      'The cores are built into the client and update with it.';

  @override
  String get invalidCidr => 'Expected a network like 192.168.1.0/24';

  @override
  String get invalidPort => 'Port 1 to 65535';

  @override
  String get invalidMtu => 'MTU 576 to 65535';

  @override
  String get secDns => 'DNS';

  @override
  String get dnsOverride => 'Own DNS servers (mihomo profiles)';

  @override
  String get dnsOverrideHint =>
      'Replaces the profile\'s DNS: queries go through the VPN by the rules, your ISP doesn\'t see them. The first lookup is a bit slower. Turn on if the profile\'s DNS misbehaves. sing-box profiles are not affected.';

  @override
  String get dnsRemote => 'Through the VPN';

  @override
  String get dnsRemoteHint =>
      'For all names. Encrypted DNS: https://…, tls://…';

  @override
  String get dnsDirect => 'Direct';

  @override
  String get dnsDirectHint =>
      'Only to find the VPN servers themselves and for direct traffic. Plain IP addresses.';

  @override
  String get invalidResolver =>
      'Expected an IP or an address like https://…/dns-query';

  @override
  String get trayExitKeepCore => 'Exit, keep the VPN on';

  @override
  String get toggleHotkey => 'Hotkey to toggle the VPN';

  @override
  String get hotkeyNone => 'Not set';

  @override
  String get hotkeySet => 'Set';

  @override
  String get hotkeyPress =>
      'Press a key combination, e.g. Ctrl + Alt + V. It works even while the window is hidden.';

  @override
  String get updates => 'Updates';

  @override
  String get checkUpdates => 'Check for updates on start';

  @override
  String get checkNow => 'Check';

  @override
  String get updateLatest => 'You have the latest version';

  @override
  String get updateNoReleases => 'No releases yet';

  @override
  String updateAvailable(String v) {
    return 'Version $v is available';
  }

  @override
  String updateTo(String v) {
    return 'Update to $v';
  }

  @override
  String updateDownloading(int p) {
    return 'Downloading the update… $p%';
  }

  @override
  String get updateHint =>
      'The client downloads the archive (through the VPN if it\'s on), closes, updates and starts again. Settings and subscriptions stay.';

  @override
  String get settingsAndroid => 'Android';

  @override
  String get vpnNotification => '“VPN is running” notification';

  @override
  String get vpnNotificationHint =>
      'Android doesn\'t let a VPN run in the background without a notification. When off, it\'s folded: no status-bar icon, at the very bottom of the shade.';

  @override
  String get vpnNotificationHide => 'Remove completely';

  @override
  String get vpnNotificationHideHint =>
      'Opens Android settings: turn off “VPN is running (folded)” there. The VPN keeps working; the key icon stays — the system shows it.';

  @override
  String get quickTile => 'Quick settings tile';

  @override
  String get quickTileHint =>
      'Open the shade, tap the pencil and drag the SolaHelm tile in. It turns the last connection on and the VPN off without opening the app.';

  @override
  String get settingsUiMode => 'Interface';

  @override
  String get uiSimple => 'Simple';

  @override
  String get uiSimpleHint =>
      'One big button: add a subscription, tap, done. You see which country your traffic comes out in and can pick a server. Nothing else in the way.';

  @override
  String get uiAdvanced => 'Advanced';

  @override
  String get uiAdvancedHint =>
      'Everything: TUN and proxy modes, core choice, rules, connections, the log, fine-tuning of the connection and the core.';

  @override
  String get welcomeTitle => 'Welcome to SolaHelm';

  @override
  String get welcomeSubtitle => 'How would you like it?';

  @override
  String get welcomeLater =>
      'You can change this any time: Settings → Interface.';

  @override
  String get settingsExit => 'Country and IP';

  @override
  String get showExitInfo => 'Show country and IP';

  @override
  String get showExitInfoHint =>
      'After connecting, the client asks ipwho.is (through the VPN) which IP and country you now go online from.';

  @override
  String get exitLocating => 'Finding your country…';

  @override
  String get exitUnknown => 'Couldn\'t get the IP';

  @override
  String get exitUnknownPlace => 'Unknown country';

  @override
  String get showIp => 'Show the whole IP';

  @override
  String get hideIp => 'Hide the IP';

  @override
  String get settingsRouting => 'Routing';

  @override
  String get routingRuDirect => 'Russia direct';

  @override
  String get routingAll => 'Everything via VPN';

  @override
  String get routingHint =>
      'For link subscriptions (universal ones): they carry no rules. “Russia direct” sends Russian sites and apps, torrents and the local network around the VPN, and blocked sites and everything else through it (legiz-ru and MetaCubeX rule sets, like the panel\'s template). Clash and sing-box profiles keep their own rules.';
}
