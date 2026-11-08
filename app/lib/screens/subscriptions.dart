import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../state/scope.dart';
import '../theme.dart';
import '../widgets/common.dart';

class SubscriptionsScreen extends StatelessWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = AppScope.of(context);
    final p = context.palette;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        SectionHeader(
          s.navSubscriptions,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (st.busySubscriptions)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            IconButton(
              tooltip: s.addSubscription,
              icon: const Icon(Icons.add),
              onPressed: () => showAddSubscriptionDialog(context),
            ),
          ]),
        ),
        if (st.subscriptions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(children: [
              Text(s.noSubscriptionsTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(s.noSubscriptions, textAlign: TextAlign.center, style: TextStyle(color: p.muted)),
            ]),
          ),
        for (final sub in st.subscriptions) ...[
          _SubscriptionCard(sub: sub, active: sub.id == st.subscription?.id, state: st),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 4),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.comingSoon))),
              icon: const Icon(Icons.qr_code_scanner, size: 18),
              label: Text(s.scanQr),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _paste(context),
              icon: const Icon(Icons.content_paste, size: 18),
              label: Text(s.pasteClipboard),
            ),
          ),
        ]),
      ],
    );
  }

  Future<void> _paste(BuildContext context) async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim() ?? '';
    if (!context.mounted) return;
    if (!_isHttp(text)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.of(context).clipboardEmpty)));
      return;
    }
    showAddSubscriptionDialog(context, initial: text);
  }
}

bool _isHttp(String v) => v.startsWith('http://') || v.startsWith('https://');

Future<void> showAddSubscriptionDialog(BuildContext context, {String initial = ''}) {
  final st = AppScope.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final added = S.of(context).subscriptionAdded;
  return showDialog<void>(
    context: context,
    builder: (_) => _AddDialog(
      initial: initial,
      onAdd: (url) async {
        final err = await st.addSubscription(url);
        if (err == null) messenger.showSnackBar(SnackBar(content: Text(added)));
        return err;
      },
    ),
  );
}

class _AddDialog extends StatefulWidget {
  const _AddDialog({required this.initial, required this.onAdd});
  final String initial;
  final Future<String?> Function(String) onAdd;

  @override
  State<_AddDialog> createState() => _AddDialogState();
}

class _AddDialogState extends State<_AddDialog> {
  late final _ctrl = TextEditingController(text: widget.initial);
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final s = S.of(context);
    final v = _ctrl.text.trim();
    setState(() => _error = v.isEmpty ? s.errorUrlEmpty : (_isHttp(v) ? null : s.errorUrlInvalid));
    if (_error != null) return;
    setState(() => _busy = true);
    final err = await widget.onAdd(v);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _busy = false;
        _error = s.errorPrefix(err);
      });
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AlertDialog(
      title: Text(s.addSubscription),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: _ctrl,
          autofocus: true,
          enabled: !_busy,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: s.subscriptionUrl,
            hintText: s.subscriptionUrlHint,
            errorText: _error,
            errorMaxLines: 3,
          ),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: Text(s.cancel)),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(s.add),
        ),
      ],
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.sub, required this.active, required this.state});
  final Subscription sub;
  final bool active;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();

    final only = sub.onlyProtocol;
    final details = <String>[
      if (sub.format != null)
        switch (sub.format!) {
          SubFormat.singBoxJson => s.formatSingBox,
          SubFormat.clashYaml => s.formatClash,
          SubFormat.links => s.formatLinks(sub.linkCount > 0 ? sub.linkCount : sub.protocols.length),
        },
      if (only != null && sub.core != null) s.reasonOnlyIn(only, sub.core!.label) else if (sub.loaded) s.reasonByFormat,
      if (sub.updatedAt != null) s.updatedAt(DateFormat.Md(locale).add_Hm().format(sub.updatedAt!)),
    ];
    final used = sub.usedGb, total = sub.totalGb;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: active ? scheme.primary : p.hairline, width: active ? 1 : 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => state.selectSubscription(sub.id),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(sub.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
              ),
              if (sub.core != null) CoreChip(sub.core!),
              PopupMenuButton<String>(
                iconSize: 18,
                onSelected: (v) => v == 'refresh' ? state.refreshSubscription(sub.id) : state.removeSubscription(sub.id),
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'refresh', child: Text(s.refresh)),
                  PopupMenuItem(value: 'delete', child: Text(s.delete)),
                ],
              ),
            ]),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(sub.loaded ? details.join(' · ') : s.subPending, style: TextStyle(fontSize: 12, color: p.muted)),
            ),
            if (used != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: total == null || total == 0 ? 0 : (used / total).clamp(0, 1),
                    minHeight: 4,
                    backgroundColor: p.panel,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Wrap(alignment: WrapAlignment.spaceBetween, spacing: 12, children: [
                  Text((total == null ? s.trafficUnlimited(formatGb(context, used)) : s.trafficOf(formatGb(context, used), formatGb(context, total))),
                      style: TextStyle(fontSize: 12, color: p.muted)),
                  Text(sub.expire == null ? s.noExpiry : s.expiresOn(formatDate(context, sub.expire!)),
                      style: TextStyle(fontSize: 12, color: p.muted)),
                ]),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
