import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../state/scope.dart';
import '../theme.dart';
import '../widgets/common.dart';

enum _Sort { time, download, upload, host, count }

/// Connections grouped by process, with drill-down, filters and details.
class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> {
  bool _byProcess = true;
  String? _process; // drilled-in process
  bool _showClosed = false;
  String _filter = '';
  _Sort _sort = _Sort.download;
  bool _desc = true;
  final _filterCtrl = TextEditingController();

  @override
  void dispose() {
    _filterCtrl.dispose();
    super.dispose();
  }

  bool _matches(ConnectionEntry c) {
    if (_filter.isEmpty) return true;
    final f = _filter;
    return c.host.toLowerCase().contains(f) ||
        c.app.toLowerCase().contains(f) ||
        c.chain.toLowerCase().contains(f) ||
        c.destIp.contains(f) ||
        c.ruleText.toLowerCase().contains(f);
  }

  void _setFilter(String v) => setState(() => _filter = v.trim().toLowerCase());

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = AppScope.of(context);
    final inProcess = _byProcess && _process != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionHeader(
          inProcess ? _process! : s.navConnections,
          trailing: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 4, children: [
            Text('↑ ${formatBytes(context, st.uploadTotal)}  ↓ ${formatBytes(context, st.downloadTotal)}',
                style: TextStyle(fontSize: 13, color: context.palette.muted)),
            const SizedBox(width: 8),
            IconButton(
              tooltip: _byProcess ? s.flatList : s.byProcess,
              icon: Icon(_byProcess ? Icons.view_list_outlined : Icons.apps_outlined),
              onPressed: () => setState(() {
                _byProcess = !_byProcess;
                _process = null;
              }),
            ),
            IconButton(
              tooltip: s.closeAll,
              icon: const Icon(Icons.cancel_outlined),
              onPressed: st.connections.isEmpty ? null : () => _confirmCloseAll(context, st),
            ),
            IconButton(
              tooltip: s.clearClosed,
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: st.closedConnections.isEmpty ? null : st.clearClosedConnections,
            ),
          ]),
        ),
        _toolbar(context, st, inProcess),
        const SizedBox(height: 8),
        Expanded(
          child: (_byProcess && !inProcess) ? _processList(context, st) : _connectionList(context, st),
        ),
      ]),
    );
  }

  Widget _toolbar(BuildContext context, AppState st, bool inProcess) {
    final s = S.of(context);
    final showTabs = !_byProcess || inProcess;
    final active = st.connections.where((c) => !inProcess || c.app == _process).length;
    final closed = st.closedConnections.where((c) => !inProcess || c.app == _process).length;
    return Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
      if (inProcess)
        TextButton.icon(
          onPressed: () => setState(() => _process = null),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: Text(s.back),
        ),
      if (!showTabs)
        Text(s.processesCount(_groups(st).length), style: const TextStyle(fontSize: 13)),
      if (showTabs)
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: false, label: Text('${s.connActive} $active')),
            ButtonSegment(value: true, label: Text('${s.connClosed} $closed')),
          ],
          selected: {_showClosed},
          onSelectionChanged: (v) => setState(() => _showClosed = v.first),
        ),
      SizedBox(
        width: 240,
        child: TextField(
          controller: _filterCtrl,
          decoration: InputDecoration(
            hintText: s.filter,
            prefixIcon: const Icon(Icons.filter_list, size: 18),
            suffixIcon: _filter.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () {
                      _filterCtrl.clear();
                      _setFilter('');
                    },
                  ),
          ),
          onChanged: _setFilter,
        ),
      ),
      DropdownButton<_Sort>(
        value: _sort,
        underline: const SizedBox.shrink(),
        items: [
          DropdownMenuItem(value: _Sort.download, child: Text(s.sortDownload)),
          DropdownMenuItem(value: _Sort.upload, child: Text(s.sortUpload)),
          DropdownMenuItem(value: _Sort.time, child: Text(s.sortTime)),
          DropdownMenuItem(value: _Sort.host, child: Text(showTabs ? s.sortHost : s.processName)),
          if (!showTabs) DropdownMenuItem(value: _Sort.count, child: Text(s.sortCount)),
        ],
        onChanged: (v) => setState(() => _sort = v ?? _Sort.download),
      ),
      IconButton(
        icon: Icon(_desc ? Icons.arrow_downward : Icons.arrow_upward, size: 18),
        onPressed: () => setState(() => _desc = !_desc),
      ),
    ]);
  }

  // ---- by process ----

  List<_ProcGroup> _groups(AppState st) {
    final map = <String, _ProcGroup>{};
    for (final c in st.connections.where(_matches)) {
      (map[c.app] ??= _ProcGroup(c.app)).add(c, active: true);
    }
    for (final c in st.closedConnections.where(_matches)) {
      (map[c.app] ??= _ProcGroup(c.app)).add(c, active: false);
    }
    final list = map.values.toList();
    int cmp(_ProcGroup a, _ProcGroup b) => switch (_sort) {
          _Sort.download => a.download.compareTo(b.download),
          _Sort.upload => a.upload.compareTo(b.upload),
          _Sort.time => a.latest.compareTo(b.latest),
          _Sort.host => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
          _Sort.count => a.active.compareTo(b.active),
        };
    list.sort((a, b) {
      // Processes with live connections first, then by the chosen key.
      if ((a.active > 0) != (b.active > 0)) return a.active > 0 ? -1 : 1;
      return _desc ? cmp(b, a) : cmp(a, b);
    });
    return list;
  }

  Widget _processList(BuildContext context, AppState st) {
    final s = S.of(context);
    final p = context.palette;
    final groups = _groups(st);
    if (groups.isEmpty) return _empty(context, st);
    return ListView.separated(
      itemCount: groups.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
        final g = groups[i];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => setState(() {
              _process = g.name;
              _showClosed = g.active == 0;
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(children: [
                AppAvatar(g.name),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(
                        child: Text(g.name,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      if (g.active > 0) CountBadge(g.active, color: p.success, tooltip: s.connActive),
                      if (g.closed > 0) ...[
                        const SizedBox(width: 4),
                        CountBadge(g.closed, tooltip: s.connClosed),
                      ],
                    ]),
                    const SizedBox(height: 2),
                    Text('↑ ${formatBytes(context, g.upload)}  ↓ ${formatBytes(context, g.download)}',
                        style: TextStyle(fontSize: 12, color: p.muted)),
                  ]),
                ),
                if (g.downSpeed + g.upSpeed > 0)
                  Text('↓ ${formatBytes(context, g.downSpeed)}/s',
                      style: TextStyle(fontSize: 12, color: p.success)),
                Icon(Icons.chevron_right, color: p.muted),
              ]),
            ),
          ),
        );
      },
    );
  }

  // ---- connections ----

  Widget _connectionList(BuildContext context, AppState st) {
    final src = _showClosed ? st.closedConnections : st.connections;
    final list = src.where((c) => (_process == null || !_byProcess || c.app == _process) && _matches(c)).toList();
    int cmp(ConnectionEntry a, ConnectionEntry b) => switch (_sort) {
          _Sort.download => a.download.compareTo(b.download),
          _Sort.upload => a.upload.compareTo(b.upload),
          _Sort.time => (a.start ?? DateTime(0)).compareTo(b.start ?? DateTime(0)),
          _Sort.host || _Sort.count => b.host.toLowerCase().compareTo(a.host.toLowerCase()),
        };
    list.sort((a, b) => _desc ? cmp(b, a) : cmp(a, b));
    if (list.isEmpty) return _empty(context, st);
    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, i) => _ConnTile(
        c: list[i],
        showApp: !_byProcess,
        onClose: list[i].active ? () => st.closeConnection(list[i].id) : null,
      ),
    );
  }

  Widget _empty(BuildContext context, AppState st) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Text(st.status == LinkStatus.connected ? s.noConnections : s.nodesNotConnected,
          textAlign: TextAlign.center, style: TextStyle(color: context.palette.muted)),
    );
  }

  Future<void> _confirmCloseAll(BuildContext context, AppState st) async {
    final s = S.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.closeAll),
        content: Text('${s.connActive}: ${st.connections.length}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.closeAll)),
        ],
      ),
    );
    if (ok == true) await st.closeAllConnections();
  }
}

class _ProcGroup {
  _ProcGroup(this.name);
  final String name;
  int active = 0, closed = 0, upload = 0, download = 0, upSpeed = 0, downSpeed = 0;
  DateTime latest = DateTime(0);

  void add(ConnectionEntry c, {required bool active}) {
    if (active) {
      this.active++;
      upSpeed += c.upSpeed;
      downSpeed += c.downSpeed;
    } else {
      closed++;
    }
    upload += c.upload;
    download += c.download;
    final t = c.start;
    if (t != null && t.isAfter(latest)) latest = t;
  }
}

class _ConnTile extends StatelessWidget {
  const _ConnTile({required this.c, required this.showApp, this.onClose});
  final ConnectionEntry c;
  final bool showApp;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = context.palette;
    final node = c.direct ? 'DIRECT' : c.chains.first;
    final meta = [
      '${c.inbound}(${c.network.toUpperCase()})',
      node,
      '↑ ${formatBytes(context, c.upload)} ↓ ${formatBytes(context, c.download)}',
      if (c.active && c.downSpeed + c.upSpeed > 0) '↓ ${formatBytes(context, c.downSpeed)}/s',
    ].join('  |  ');
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: c.active ? p.success.withValues(alpha: 0.35) : p.hairline, width: 0.5),
      ),
      child: InkWell(
        onTap: () => showConnectionDetails(context, c),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(children: [
            if (showApp) ...[AppAvatar(c.app, size: 28), const SizedBox(width: 10)],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(showApp ? '${c.hostPort}  ·  ${c.app}' : c.hostPort,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(meta, style: TextStyle(fontSize: 12, color: p.muted), overflow: TextOverflow.ellipsis),
              ]),
            ),
            Text(timeAgo(context, c.start), style: TextStyle(fontSize: 11, color: p.muted)),
            if (onClose != null)
              IconButton(
                tooltip: s.closeConnection,
                icon: Icon(Icons.close, size: 18, color: p.warning),
                onPressed: onClose,
              )
            else
              const SizedBox(width: 12),
          ]),
        ),
      ),
    );
  }
}

Future<void> showConnectionDetails(BuildContext context, ConnectionEntry c) {
  final s = S.of(context);
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      final p = ctx.palette;
      Widget section(String title, List<(String, String)> rows) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 6),
                child: Text(title.toUpperCase(),
                    style: TextStyle(fontSize: 11, letterSpacing: 0.6, color: p.muted, fontWeight: FontWeight.w500)),
              ),
              Container(
                decoration: BoxDecoration(color: p.panel, borderRadius: BorderRadius.circular(8)),
                child: Column(children: [
                  for (var i = 0; i < rows.length; i++)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: i == 0 ? null : Border(top: BorderSide(color: p.hairline, width: 0.5)),
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(rows[i].$1, style: TextStyle(fontSize: 13, color: p.muted)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: SelectableText(rows[i].$2.isEmpty ? '—' : rows[i].$2,
                              textAlign: TextAlign.right, style: const TextStyle(fontSize: 13)),
                        ),
                      ]),
                    ),
                ]),
              ),
            ],
          );
      return AlertDialog(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${c.app} → ${c.host}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            CountBadge.label(c.active ? s.statusActive : s.statusClosed, color: c.active ? p.success : null),
            CountBadge.label('${c.inbound}(${c.network.toUpperCase()})'),
            Text(timeAgo(ctx, c.start), style: TextStyle(fontSize: 12, color: p.muted)),
          ]),
        ]),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              section(s.secTraffic, [
                (s.upSpeed, '${formatBytes(ctx, c.upSpeed)}/s'),
                (s.downSpeed, '${formatBytes(ctx, c.downSpeed)}/s'),
                (s.uploaded, formatBytes(ctx, c.upload)),
                (s.downloaded, formatBytes(ctx, c.download)),
              ]),
              section(s.secRouting, [
                (s.rule, c.ruleText),
                (s.chain, c.chain),
                (s.connType, '${c.inbound}(${c.network})'),
              ]),
              section(s.secNetwork, [
                (s.host, c.host),
                (s.destIp, c.destIp),
                (s.destPort, c.port),
                (s.srcIp, c.srcIp),
                (s.srcPort, c.srcPort),
                if (c.remote.isNotEmpty) (s.remote, c.remote),
              ]),
              section(s.secProcess, [
                (s.processName, c.app),
                (s.processPath, c.processPath),
                (s.started, c.start == null ? '' : formatDateTime(ctx, c.start!)),
              ]),
            ]),
          ),
        ),
        actions: [FilledButton.tonal(onPressed: () => Navigator.pop(ctx), child: Text(s.close))],
      );
    },
  );
}
