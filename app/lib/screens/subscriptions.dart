import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../desktop.dart';
import '../l10n/app_localizations.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../state/scope.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'profile_editor.dart';
import 'qr_camera.dart';
import 'rules.dart';

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
              onPressed: () => _importFile(context),
              icon: const Icon(Icons.file_open_outlined, size: 18),
              label: Text(s.importFile),
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
          const SizedBox(width: 8),
          Expanded(
            child: MenuAnchor(
              builder: (context, menu, _) => OutlinedButton.icon(
                onPressed: () => menu.isOpen ? menu.close() : menu.open(),
                icon: const Icon(Icons.qr_code_scanner, size: 18),
                label: const Text('QR'),
              ),
              menuChildren: [
                if (Platform.isAndroid)
                  MenuItemButton(
                    leadingIcon: const Icon(Icons.photo_camera_outlined),
                    onPressed: () => _scanCamera(context),
                    child: Text(s.qrCamera),
                  ),
                if (DesktopShell.supported)
                  MenuItemButton(
                    leadingIcon: const Icon(Icons.screenshot_monitor_outlined),
                    onPressed: () => _scanScreen(context),
                    child: Text(s.qrScreen),
                  ),
                MenuItemButton(
                  leadingIcon: const Icon(Icons.image_outlined),
                  onPressed: () => _scanImage(context),
                  child: Text(Platform.isAndroid ? s.qrGallery : s.qrImageFile),
                ),
              ],
            ),
          ),
        ]),
      ],
    );
  }

  /// A link opens the add dialog; anything else is tried as config text
  /// (sing-box JSON, Clash YAML or a list of share links).
  Future<void> _paste(BuildContext context) async {
    final s = S.of(context);
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim() ?? '';
    if (!context.mounted) return;
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.clipboardEmpty)));
      return;
    }
    await _addText(context, text, s.pastedName(_now(context)));
  }

  String _now(BuildContext context) =>
      DateFormat.Md(Localizations.localeOf(context).toString()).add_Hm().format(DateTime.now());

  /// A subscription link opens the add dialog (to confirm it); share links
  /// or config text become a profile named [name].
  Future<void> _addText(BuildContext context, String text, String name) async {
    final s = S.of(context);
    final st = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (_isHttp(text) && !text.contains('\n')) {
      showAddSubscriptionDialog(context, initial: text);
      return;
    }
    final err = await st.importText(text, name: name);
    messenger.showSnackBar(SnackBar(content: Text(err == null ? s.profileAdded : s.errorPrefix(err))));
  }

  /// QR codes found: a subscription link is offered in the add dialog;
  /// share links (one per code) are added together as one profile.
  Future<void> _addQrTexts(BuildContext context, List<String> texts) async {
    final s = S.of(context);
    if (!context.mounted) return;
    if (texts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.qrNotFound)));
      return;
    }
    final links = texts.where((t) => _isHttp(t) && !t.contains('\n')).toList();
    final rest = texts.where((t) => !links.contains(t)).toList();
    if (rest.isEmpty) {
      showAddSubscriptionDialog(context, initial: links.first);
      return;
    }
    await _addText(context, rest.join('\n'), s.qrName(_now(context)));
  }

  Future<void> _scanCamera(BuildContext context) async {
    final text = await QrCameraPage.open(context);
    if (text == null || !context.mounted) return;
    await _addQrTexts(context, [text]);
  }

  Future<void> _scanScreen(BuildContext context) async {
    final s = S.of(context);
    final st = AppScope.of(context);
    try {
      final shell = DesktopShell.instance;
      final texts = shell == null ? await st.backend.qrScreen() : await shell.whileHidden(st.backend.qrScreen);
      if (context.mounted) await _addQrTexts(context, texts);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.errorPrefix(e.toString()))));
      }
    }
  }

  Future<void> _scanImage(BuildContext context) async {
    final s = S.of(context);
    final st = AppScope.of(context);
    const images = XTypeGroup(
      label: 'images',
      extensions: ['png', 'jpg', 'jpeg', 'gif', 'webp'],
      mimeTypes: ['image/png', 'image/jpeg', 'image/gif', 'image/webp'],
    );
    final file = await openFile(acceptedTypeGroups: const [images]);
    if (file == null) return;
    try {
      final texts = await st.backend.qrImage(await file.readAsBytes());
      if (context.mounted) await _addQrTexts(context, texts);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.errorPrefix(e.toString()))));
      }
    }
  }

  Future<void> _importFile(BuildContext context) async {
    final s = S.of(context);
    final st = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    const group = XTypeGroup(label: 'config', extensions: ['yaml', 'yml', 'json', 'txt', 'conf']);
    final file = await openFile(acceptedTypeGroups: const [group, XTypeGroup(label: '*')]);
    if (file == null) return;
    final err = await st.importFile(file.path);
    messenger.showSnackBar(SnackBar(content: Text(err == null ? s.profileAdded : s.errorPrefix(err))));
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

    final details = <String>[
      if (sub.format != null)
        switch (sub.format!) {
          SubFormat.singBoxJson => s.formatSingBox,
          SubFormat.clashYaml => s.formatClash,
          SubFormat.links => s.formatLinks(sub.linkCount > 0 ? sub.linkCount : sub.protocols.length),
        },
      if (sub.unsupported.isNotEmpty) s.linksSkipped(sub.unsupported.join(', ')) else if (sub.loaded) s.reasonByFormat,
      if (sub.updatedAt != null) s.updatedAt(DateFormat.Md(locale).add_Hm().format(sub.updatedAt!)),
    ];
    final badges = <Widget>[
      if (sub.source == SubSource.file) CountBadge.label(s.sourceFile),
      if (sub.source == SubSource.pasted) CountBadge.label(s.sourcePasted),
      if (sub.edited) CountBadge.label(s.editedBadge, color: p.warning),
      if (sub.rules != null) CountBadge.label(s.rulesBadge, color: p.success),
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
                onSelected: (v) => switch (v) {
                  'open' => ProfileEditorPage.open(context, state, sub.id),
                  'rules' => RulesEditorPage.open(context, state, sub.id),
                  'refresh' => state.refreshSubscription(sub.id),
                  _ => state.removeSubscription(sub.id),
                },
                itemBuilder: (_) => [
                  if (sub.loaded && !state.settings.simple) PopupMenuItem(value: 'open', child: Text(s.menuOpen)),
                  if (sub.loaded && !state.settings.simple) PopupMenuItem(value: 'rules', child: Text(s.menuRules)),
                  if (sub.refreshable) PopupMenuItem(value: 'refresh', child: Text(s.refresh)),
                  PopupMenuItem(value: 'delete', child: Text(s.delete)),
                ],
              ),
            ]),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(sub.loaded ? details.join(' · ') : s.subPending, style: TextStyle(fontSize: 12, color: p.muted)),
            ),
            if (badges.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: badges),
            ],
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
