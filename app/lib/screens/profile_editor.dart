import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

const _mono = TextStyle(
  fontFamily: 'Consolas',
  fontFamilyFallback: ['Menlo', 'DejaVu Sans Mono', 'monospace'],
  fontSize: 13,
  height: 1.35,
);

/// View and edit a profile's config text; the core checks it before saving.
class ProfileEditorPage extends StatefulWidget {
  const ProfileEditorPage({super.key, required this.state, required this.subId});
  final AppState state;
  final String subId;

  static Future<void> open(BuildContext context, AppState state, String subId) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ProfileEditorPage(state: state, subId: subId)),
      );

  @override
  State<ProfileEditorPage> createState() => _ProfileEditorPageState();
}

class _ProfileEditorPageState extends State<ProfileEditorPage> {
  final _ctrl = TextEditingController();
  String _original = '';
  bool _loading = true;
  bool _busy = false;
  String? _result; // check result or error
  bool _resultOk = false;

  Subscription? get _sub {
    for (final s in widget.state.subscriptions) {
      if (s.id == widget.subId) return s;
    }
    return null;
  }

  bool get _dirty => _ctrl.text != _original;

  @override
  void initState() {
    super.initState();
    widget.state.profileContent(widget.subId).then((text) {
      if (!mounted) return;
      setState(() {
        _original = text ?? '';
        _ctrl.text = _original;
        _loading = false;
      });
    });
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _formatName(S s, SubFormat? f) => switch (f) {
        SubFormat.singBoxJson => s.formatSingBox,
        SubFormat.clashYaml => s.formatClash,
        SubFormat.links => s.formatLinksShort,
        null => '?',
      };

  Future<void> _check() async {
    final s = S.of(context);
    setState(() => _busy = true);
    try {
      final v = await widget.state.backend.validate(_ctrl.text);
      setState(() {
        _resultOk = v.ok;
        _result = !v.ok
            ? s.errorPrefix(v.error ?? '?')
            : v.format == SubFormat.links
                ? s.checkOkLinks(v.converted)
                : s.checkOk(_formatName(s, v.format), v.core?.label ?? '?');
      });
    } catch (e) {
      setState(() {
        _resultOk = false;
        _result = s.errorPrefix(e.toString());
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final s = S.of(context);
    setState(() => _busy = true);
    final err = await widget.state.saveProfileContent(widget.subId, _ctrl.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _resultOk = err == null;
      _result = err == null ? s.saved : s.errorPrefix(err);
      if (err == null) _original = _ctrl.text;
    });
  }

  Future<void> _rename() async {
    final s = S.of(context);
    final sub = _sub;
    if (sub == null) return;
    final ctrl = TextEditingController(text: sub.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.rename),
        content: SizedBox(
          width: 380,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(labelText: s.nameLabel),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: Text(s.save)),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      await widget.state.renameSubscription(widget.subId, name);
      if (mounted) setState(() {});
    }
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    final s = S.of(context);
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.unsavedTitle),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.discard)),
        ],
      ),
    );
    return leave == true;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = context.palette;
    final sub = _sub;
    if (sub == null) return const Scaffold();

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(sub.name, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(tooltip: s.rename, icon: const Icon(Icons.drive_file_rename_outline), onPressed: _rename),
            const SizedBox(width: 8),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              if (sub.core != null) CoreChip(sub.core!),
              CountBadge.label(_formatName(s, sub.format)),
              if (sub.source == SubSource.file) CountBadge.label(s.sourceFile),
              if (sub.source == SubSource.pasted) CountBadge.label(s.sourcePasted),
              if (sub.edited) CountBadge.label(s.editedBadge, color: p.warning),
              if (sub.url.isNotEmpty)
                Text(sub.url, style: TextStyle(fontSize: 12, color: p.muted), overflow: TextOverflow.ellipsis),
            ]),
            if (sub.source == SubSource.remote) ...[
              const SizedBox(height: 8),
              Text(s.editedWarning, style: TextStyle(fontSize: 12, color: p.warning)),
            ],
            const SizedBox(height: 10),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TextField(
                      controller: _ctrl,
                      expands: true,
                      maxLines: null,
                      minLines: null,
                      textAlignVertical: TextAlignVertical.top,
                      style: _mono,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: Text(_result ?? '',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: _resultOk ? p.success : p.danger)),
              ),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: _busy || _loading ? null : _check, child: Text(s.check)),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _busy || _loading || !_dirty ? null : _save,
                child: _busy
                    ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(s.save),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
