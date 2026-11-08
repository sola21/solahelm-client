import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models.dart';
import '../state/scope.dart';
import '../theme.dart';
import '../widgets/common.dart';

class NodesScreen extends StatelessWidget {
  const NodesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = AppScope.of(context);
    final p = context.palette;
    final g = st.group;
    final nodes = st.groupNodes;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        SectionHeader(
          s.navNodes,
          trailing: OutlinedButton.icon(
            onPressed: (st.pinging || nodes.isEmpty) ? null : st.pingAll,
            icon: const Icon(Icons.bolt, size: 18),
            label: Text(s.ping),
          ),
        ),
        if (st.status != LinkStatus.connected || g == null)
          Padding(
            padding: const EdgeInsets.only(top: 32),
            child: Text(s.nodesNotConnected, textAlign: TextAlign.center, style: TextStyle(color: p.muted)),
          )
        else ...[
          if (st.groups.length > 1)
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final x in st.groups)
                ChoiceChip(
                  label: Text(x.name),
                  selected: x.name == g.name,
                  onSelected: (_) => st.showGroup(x.name),
                ),
            ]),
          const SizedBox(height: 8),
          Text(
            s.groupLabel('${g.name} · ${groupTypeText(s, g.type)}'),
            style: TextStyle(fontSize: 13, color: p.muted),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(children: [
              for (var i = 0; i < nodes.length; i++) ...[
                if (i > 0) const Divider(),
                ListTile(
                  dense: true,
                  selected: nodes[i].name == g.now,
                  selectedColor: Theme.of(context).colorScheme.onSurface,
                  leading: SizedBox(
                    width: 20,
                    child: nodes[i].name == g.now ? Icon(Icons.check, size: 18, color: p.success) : null,
                  ),
                  title: Text(nodes[i].name, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
                  subtitle: Text(nodes[i].type, style: TextStyle(fontSize: 12, color: p.muted)),
                  trailing: LatencyText(nodes[i]),
                  onTap: g.selectable ? () => st.selectNode(nodes[i].name) : null,
                ),
              ],
            ]),
          ),
        ],
      ],
    );
  }
}

String groupTypeText(S s, String type) => switch (type.toLowerCase()) {
      'selector' => s.groupSelector,
      'urltest' => s.groupUrlTest,
      'fallback' => s.groupFallback,
      'loadbalance' => s.groupLoadBalance,
      _ => type,
    };
