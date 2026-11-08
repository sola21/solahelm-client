import 'dart:async';

import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'models.dart';
import 'screens/connections.dart';
import 'screens/home.dart';
import 'screens/logs.dart';
import 'screens/rules.dart';
import 'screens/nodes.dart';
import 'screens/settings.dart';
import 'screens/subscriptions.dart';
import 'state/app_state.dart';
import 'state/scope.dart';
import 'theme.dart';
import 'widgets/common.dart';

enum Section { home, nodes, subscriptions, connections, rules, logs, settings }

/// Phones and narrow windows get a bottom bar with four sections;
/// wide windows get a sidebar with all of them.
class Shell extends StatefulWidget {
  const Shell({super.key});

  static const wideBreakpoint = 720.0;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  Section _section = Section.home;
  StreamSubscription<Notice>? _notices;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _notices ??= AppScope.of(context).notices.listen(_onNotice);
  }

  @override
  void dispose() {
    _notices?.cancel();
    super.dispose();
  }

  void _onNotice(Notice n) {
    if (!mounted) return;
    final s = S.of(context);
    // The newest message replaces whatever is showing instead of queueing behind it.
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    switch (n.kind) {
      case NoticeKind.info:
        final text = n.message == 'no-subscription'
            ? s.needSubscription
            : n.message.startsWith('update:')
                ? s.updateAvailable(n.message.substring(7))
                : n.message;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
        if (n.message == 'no-subscription') setState(() => _section = Section.subscriptions);
      case NoticeKind.error:
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(n.message == AppState.notElevated ? s.notElevated : s.errorPrefix(n.message)),
          duration: const Duration(seconds: 8),
        ));
    }
  }


  static const _mobile = [Section.home, Section.nodes, Section.subscriptions, Section.rules, Section.settings];

  (String, IconData) _meta(S s, Section x) => switch (x) {
        Section.home => (s.navHome, Icons.home_outlined),
        Section.nodes => (s.navNodes, Icons.format_list_bulleted),
        Section.subscriptions => (s.navSubscriptions, Icons.rss_feed),
        Section.connections => (s.navConnections, Icons.swap_horiz),
        Section.rules => (s.navRules, Icons.alt_route),
        Section.logs => (s.navLogs, Icons.article_outlined),
        Section.settings => (s.navSettings, Icons.settings_outlined),
      };

  Widget _body(S s, Section x, bool wide) => switch (x) {
        Section.home => HomeScreen(wide: wide),
        Section.nodes => const NodesScreen(),
        Section.subscriptions => const SubscriptionsScreen(),
        Section.settings => const SettingsScreen(),
        Section.connections => const ConnectionsScreen(),
        Section.rules => const RulesScreen(),
        Section.logs => const LogsScreen(),
      };

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= Shell.wideBreakpoint;
      var section = _section;
      if (!wide && !_mobile.contains(section)) section = Section.home;

      if (!wide) {
        return Scaffold(
          body: SafeArea(child: _body(s, section, false)),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _mobile.indexOf(section),
            onDestinationSelected: (i) => setState(() => _section = _mobile[i]),
            destinations: [
              for (final x in _mobile) NavigationDestination(icon: Icon(_meta(s, x).$2), label: _meta(s, x).$1),
            ],
          ),
        );
      }

      final p = context.palette;
      return Scaffold(
        body: Row(children: [
          Container(
            width: 208,
            color: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                child: Text(s.appTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
              ),
              for (final x in Section.values)
                _SideItem(
                  icon: _meta(s, x).$2,
                  label: _meta(s, x).$1,
                  selected: x == section,
                  onTap: () => setState(() => _section = x),
                ),
              const Spacer(),
              const _SideStatus(),
            ]),
          ),
          VerticalDivider(width: 0.5, thickness: 0.5, color: p.hairline),
          Expanded(child: _body(s, section, true)),
        ]),
      );
    });
  }
}

class _SideItem extends StatelessWidget {
  const _SideItem({required this.icon, required this.label, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? p.panel : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(children: [
              Icon(icon, size: 18, color: selected ? null : p.muted),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Connection status pinned to the bottom of the sidebar.
class _SideStatus extends StatelessWidget {
  const _SideStatus();

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final s = S.of(context);
    final p = context.palette;
    final on = st.status == LinkStatus.connected;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(children: [
        Icon(Icons.circle, size: 10, color: on ? p.success : p.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(on ? s.statusConnected : s.statusDisconnected, style: TextStyle(fontSize: 13, color: p.muted)),
        ),
        CoreChip(st.core),
      ]),
    );
  }
}
