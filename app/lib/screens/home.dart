import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../state/scope.dart';
import '../theme.dart';
import '../widgets/common.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.wide});
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    return wide ? _WideHome(st) : _NarrowHome(st);
  }
}

String _statusText(S s, LinkStatus status) => switch (status) {
      LinkStatus.disconnected => s.statusDisconnected,
      LinkStatus.connecting => s.statusConnecting,
      LinkStatus.connected => s.statusConnected,
      LinkStatus.disconnecting => s.statusDisconnecting,
    };

String _modeText(S s, AppState st, ProxyMode m) => switch (m) {
      ProxyMode.tun => s.modeTun,
      ProxyMode.systemProxy => s.modeSystemProxy,
      ProxyMode.portOnly => s.modePortOnly(st.coreStatus.port ?? 7890),
    };

String _nodeText(ProxyNode? n) => n == null ? '—' : (n.type.isEmpty ? n.name : '${n.name} · ${n.type}');

class _NarrowHome extends StatelessWidget {
  const _NarrowHome(this.st);
  final AppState st;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = context.palette;
    final node = st.node;
    final connected = st.status == LinkStatus.connected;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        Row(children: [
          Expanded(child: Text(s.appTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500))),
          CoreChip(st.core, auto: st.coreIsAuto),
        ]),
        if (st.isDemo) ...[const SizedBox(height: 12), const DemoBanner()],
        const SizedBox(height: 40),
        Center(child: PowerButton(status: st.status, onTap: st.toggleConnection)),
        const SizedBox(height: 16),
        Center(
          child: Text(_statusText(s, st.status), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ),
        const SizedBox(height: 2),
        Center(
          child: Text(
            connected ? s.connectedFor(formatDuration(st.connectedFor), st.core.label) : s.tapToConnect,
            style: TextStyle(fontSize: 13, color: p.muted),
          ),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: p.panel, borderRadius: BorderRadius.circular(8)),
          child: Column(children: [
            Row(children: [
              const Icon(Icons.dns_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_nodeText(node), style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
              ),
              if (node != null) LatencyText(node),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: Text('${s.modeLabel}: ${_modeText(s, st, st.mode)}',
                    style: TextStyle(fontSize: 12, color: p.muted), overflow: TextOverflow.ellipsis),
              ),
              if (st.subscription != null)
                Flexible(
                  child: Text(st.subscription!.name,
                      style: TextStyle(fontSize: 12, color: p.muted), overflow: TextOverflow.ellipsis),
                ),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          const Icon(Icons.arrow_upward, size: 16),
          const SizedBox(width: 4),
          Text(s.kbps(st.upKbps), style: const TextStyle(fontSize: 13)),
          const Spacer(),
          const Icon(Icons.arrow_downward, size: 16),
          const SizedBox(width: 4),
          Text(s.kbps(st.downKbps), style: const TextStyle(fontSize: 13)),
        ]),
      ],
    );
  }
}

class _WideHome extends StatelessWidget {
  const _WideHome(this.st);
  final AppState st;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = context.palette;
    final sub = st.subscription;
    final node = st.node;
    final connected = st.status == LinkStatus.connected;
    final busy = st.status.busy;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (st.isDemo) ...[const DemoBanner(), const SizedBox(height: 16)],
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                connected
                    ? '${_statusText(s, st.status)} · ${formatDuration(st.connectedFor)}'
                    : _statusText(s, st.status),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 4, children: [
                if (sub != null) Text(sub.name, style: TextStyle(fontSize: 13, color: p.muted)),
                CoreChip(st.core),
                Text(
                  st.coreIsAuto ? s.coreChosenAuto(st.core.label) : s.coreChosenManual(st.core.label),
                  style: TextStyle(fontSize: 13, color: p.muted),
                ),
                if (connected && st.coreStatus.port != null)
                  Text('· ${s.localPort(st.coreStatus.port!)}', style: TextStyle(fontSize: 13, color: p.muted)),
                if (st.coreStatus.elevated)
                  Text('· ${s.adminBadge}', style: TextStyle(fontSize: 13, color: p.warning)),
              ]),
            ]),
          ),
          const SizedBox(width: 16),
          SizedBox(
            height: 40,
            child: connected || busy
                ? OutlinedButton.icon(
                    onPressed: busy ? null : st.toggleConnection,
                    icon: busy
                        ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.power_settings_new, size: 18),
                    label: Text(busy ? _statusText(s, st.status) : s.disconnect),
                  )
                : FilledButton.icon(
                    onPressed: st.toggleConnection,
                    icon: const Icon(Icons.power_settings_new, size: 18),
                    label: Text(s.connect),
                  ),
          ),
        ]),
        const SizedBox(height: 20),
        SegmentedButton<ProxyMode>(
          showSelectedIcon: false,
          segments: [
            for (final m in ProxyMode.values) ButtonSegment(value: m, label: Text(_modeText(s, st, m))),
          ],
          selected: {st.mode},
          onSelectionChanged: busy ? null : (v) => st.setMode(v.first),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth > 640 ? 4 : 2;
          final w = (c.maxWidth - 12 * (cols - 1)) / cols;
          final used = sub?.usedGb, total = sub?.totalGb;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(
              width: w,
              child: MetricTile(
                label: s.metricNode,
                child: Text(_nodeText(node), overflow: TextOverflow.ellipsis),
              ),
            ),
            SizedBox(
              width: w,
              child: MetricTile(
                label: s.metricLatency,
                child: node == null
                    ? const Text('—')
                    : LatencyText(node, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              ),
            ),
            SizedBox(
              width: w,
              child: MetricTile(
                label: s.metricSpeed,
                child: Text('↓ ${s.kbps(st.downKbps)}  ↑ ${s.kbps(st.upKbps)}', overflow: TextOverflow.ellipsis),
              ),
            ),
            SizedBox(
              width: w,
              child: MetricTile(
                label: s.metricTraffic,
                child: Text(used == null
                    ? '—'
                    : (total == null ? s.trafficUnlimited(formatGb(context, used)) : s.trafficOf(formatGb(context, used), formatGb(context, total)))),
              ),
            ),
          ]);
        }),
        const SizedBox(height: 24),
        Text(s.recentConnections, style: TextStyle(fontSize: 13, color: p.muted)),
        const SizedBox(height: 8),
        if (st.connections.isEmpty)
          Text(connected ? s.noConnections : s.nodesNotConnected, style: TextStyle(fontSize: 13, color: p.muted)),
        for (final c in st.connections.take(8)) ConnectionRow(c),
      ],
    );
  }
}

class ConnectionRow extends StatelessWidget {
  const ConnectionRow(this.c, {super.key});
  final ConnectionEntry c;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = context.palette;
    final via = c.direct ? s.routeDirect : s.routeVia(c.chains.first);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: p.hairline, width: 0.5))),
      child: Row(children: [
        Expanded(
          child: Text(c.host,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: 'Consolas', fontFamilyFallback: ['Menlo', 'DejaVu Sans Mono', 'monospace'], fontSize: 13)),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(via, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: p.muted)),
        ),
      ]),
    );
  }
}

/// The big round connect button on phones.
class PowerButton extends StatelessWidget {
  const PowerButton({super.key, required this.status, required this.onTap});
  final LinkStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final on = status == LinkStatus.connected;
    final color = status.busy ? p.muted : (on ? p.success : scheme.onSurface);
    return Semantics(
      button: true,
      label: on ? S.of(context).disconnect : S.of(context).connect,
      child: Material(
        color: status.busy ? p.panel : scheme.surface,
        shape: CircleBorder(side: BorderSide(color: on ? p.success : p.hairline, width: 2)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: status.busy ? null : onTap,
          child: SizedBox.square(
            dimension: 132,
            child: status.busy
                ? Padding(padding: const EdgeInsets.all(44), child: CircularProgressIndicator(color: color))
                : Icon(Icons.power_settings_new, size: 52, color: color),
          ),
        ),
      ),
    );
  }
}
