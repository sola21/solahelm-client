import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../state/scope.dart';
import '../theme.dart';
import '../widgets/common.dart';

const _mono = TextStyle(
  fontFamily: 'Consolas',
  fontFamilyFallback: ['Menlo', 'DejaVu Sans Mono', 'monospace'],
  fontSize: 13,
  height: 1.35,
);

String routingText(S s, String m) => switch (m) {
      'global' => s.routingGlobal,
      'direct' => s.routingDirect,
      _ => s.routingRule,
    };

/// Rules in effect, with a filter, the routing mode and a way into the editor.
class RulesScreen extends StatefulWidget {
  const RulesScreen({super.key});

  @override
  State<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends State<RulesScreen> {
  String _filter = '';
  Future<ProfileRulesInfo>? _profile; // rules of the profile while disconnected
  String? _profileFor;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = AppScope.of(context);
    final p = context.palette;
    final sub = st.subscription;
    final connected = st.status == LinkStatus.connected;

    if (!connected && sub != null && sub.loaded && _profileFor != '${sub.id}:${sub.rules?.length}') {
      _profileFor = '${sub.id}:${sub.rules?.length}';
      _profile = st.profileRules(sub.id);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionHeader(
          s.navRules,
          trailing: FilledButton.tonalIcon(
            onPressed: sub == null || !sub.loaded ? null : () => RulesEditorPage.open(context, st, sub.id),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(s.rulesEdit),
          ),
        ),
        Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(
            width: 300,
            child: TextField(
              decoration: InputDecoration(hintText: s.filter, prefixIcon: const Icon(Icons.filter_list, size: 18)),
              onChanged: (v) => setState(() => _filter = v.trim().toLowerCase()),
            ),
          ),
          if (connected && st.routingMode != null)
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                for (final m in const ['rule', 'global', 'direct'])
                  ButtonSegment(value: m, label: Text(routingText(s, m))),
              ],
              selected: {st.routingMode!},
              onSelectionChanged: (v) => st.setRoutingMode(v.first),
            ),
          if (sub?.rules != null) CountBadge.label(s.rulesBadge, color: p.success),
        ]),
        const SizedBox(height: 8),
        if (sub == null)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Text(s.needSubscription, textAlign: TextAlign.center, style: TextStyle(color: p.muted)),
          )
        else if (connected)
          Expanded(child: _list(context, [for (final r in st.activeRules) (r.type, r.payload, r.proxy)]))
        else
          Expanded(
            child: FutureBuilder<ProfileRulesInfo>(
              future: _profile,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Text(s.errorPrefix('${snap.error}'), style: TextStyle(color: p.danger));
                }
                final info = snap.data;
                if (info == null) return const Center(child: CircularProgressIndicator());
                final lines = sub.rules == null
                    ? info.rules
                    : (sub.rulesReplace ? sub.rules! : [...sub.rules!, ...info.rules]);
                final rows = <(String, String, String)>[
                  for (final l in lines)
                    if (RuleLine.parse(l) case final r?) (r.type, r.payload, r.target),
                  for (final l in info.readOnly) ('sing-box', l, ''),
                ];
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(s.rulesNotConnectedHint, style: TextStyle(fontSize: 12, color: p.muted)),
                  const SizedBox(height: 8),
                  Expanded(child: _list(context, rows)),
                ]);
              },
            ),
          ),
      ]),
    );
  }

  Widget _list(BuildContext context, List<(String, String, String)> all) {
    final s = S.of(context);
    final p = context.palette;
    final rows = _filter.isEmpty
        ? all
        : all.where((r) => '${r.$1} ${r.$2} ${r.$3}'.toLowerCase().contains(_filter)).toList();
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Text(s.rulesNone, textAlign: TextAlign.center, style: TextStyle(color: p.muted)),
      );
    }
    return ListView.separated(
      itemCount: rows.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
        if (i == 0) return Text(s.rulesCount(rows.length), style: TextStyle(fontSize: 12, color: p.muted));
        final r = rows[i - 1];
        final match = r.$1.toUpperCase() == 'MATCH';
        return Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(match ? '*' : r.$2, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis, maxLines: 2),
              const SizedBox(height: 4),
              Wrap(spacing: 6, children: [
                CountBadge.label(r.$1),
                if (r.$3.isNotEmpty) CountBadge.label(r.$3, color: _targetColor(p, r.$3)),
              ]),
            ]),
          ),
        );
      },
    );
  }
}

Color? _targetColor(AppPalette p, String target) => switch (target.toUpperCase()) {
      'DIRECT' => null,
      'REJECT' || 'REJECT-DROP' => p.danger,
      _ => p.success,
    };

/// Edits a profile's rules (kept apart from the subscription).
class RulesEditorPage extends StatefulWidget {
  const RulesEditorPage({super.key, required this.state, required this.subId, this.prefill});
  final AppState state;
  final String subId;
  final RuleLine? prefill;

  static Future<void> open(BuildContext context, AppState state, String subId, {RuleLine? prefill}) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => RulesEditorPage(state: state, subId: subId, prefill: prefill),
      ));

  @override
  State<RulesEditorPage> createState() => _RulesEditorPageState();
}

class _RulesEditorPageState extends State<RulesEditorPage> {
  ProfileRulesInfo? _info;
  String? _loadError;
  List<RuleLine> _rules = [];
  List<String> _initial = [];
  bool _reset = false; // "restore profile rules" pressed

  // form
  String _type = 'DOMAIN-SUFFIX';
  final _payload = TextEditingController();
  final _target = TextEditingController(text: 'DIRECT');
  bool _noResolve = false;
  String? _formError;

  // list
  String _search = '';
  bool _textMode = false;
  final _text = TextEditingController();
  String? _saveError;
  bool _saving = false;

  Subscription? get _sub {
    for (final s in widget.state.subscriptions) {
      if (s.id == widget.subId) return s;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final pf = widget.prefill;
    if (pf != null) {
      _type = pf.type;
      _payload.text = pf.payload;
      _target.text = pf.target;
    }
    widget.state.profileRules(widget.subId).then((info) {
      if (!mounted) return;
      final sub = _sub;
      final lines = sub?.rules ?? (info.replace ? info.rules : const <String>[]);
      setState(() {
        _info = info;
        _rules = [for (final l in lines) ?RuleLine.parse(l)];
        _initial = _rules.map((r) => r.toString()).toList();
        if (!info.types.contains(_type) && info.types.isNotEmpty) _type = info.types.first;
      });
    }, onError: (Object e) {
      if (mounted) setState(() => _loadError = e.toString());
    });
  }

  @override
  void dispose() {
    _payload.dispose();
    _target.dispose();
    _text.dispose();
    super.dispose();
  }

  bool get _dirty => _reset || _rules.map((r) => r.toString()).join('\n') != _initial.join('\n') || _textMode;

  String _hint(String type) => switch (type) {
        'DOMAIN' => 'www.example.com',
        'DOMAIN-SUFFIX' => 'example.com',
        'DOMAIN-KEYWORD' => 'google',
        'DOMAIN-REGEX' => r'^.*\.example\.com$',
        'DOMAIN-WILDCARD' => '*.example.com',
        'GEOSITE' => 'youtube',
        'GEOIP' => 'RU',
        'IP-CIDR' || 'SRC-IP-CIDR' => '192.168.1.0/24',
        'IP-CIDR6' => '2001:db8::/32',
        'IP-ASN' => '13335',
        'DST-PORT' || 'SRC-PORT' || 'IN-PORT' => '22',
        'PROCESS-NAME' => 'Telegram.exe',
        'PROCESS-PATH' => r'C:\Program Files\App\app.exe',
        'NETWORK' => 'udp',
        'RULE-SET' => 'geosite-ru',
        _ => '',
      };

  RuleLine? _formRule() {
    final s = S.of(context);
    final target = _target.text.trim();
    final payload = _payload.text.trim();
    if (_type != 'MATCH' && payload.isEmpty) {
      setState(() => _formError = s.payloadEmpty);
      return null;
    }
    if (payload.contains(',') || target.isEmpty || target.contains(',')) {
      setState(() => _formError = s.ruleInvalid(0, '$_type,$payload,$target'));
      return null;
    }
    setState(() => _formError = null);
    return RuleLine(type: _type, payload: payload, target: target, noResolve: _noResolve);
  }

  void _add({required bool top}) {
    final r = _formRule();
    if (r == null) return;
    setState(() {
      _syncFromText();
      top ? _rules.insert(0, r) : _rules.add(r);
      _payload.clear();
    });
  }

  /// Leaves text mode, parsing the lines. Returns false on a bad line.
  bool _syncFromText() {
    if (!_textMode) return true;
    final s = S.of(context);
    final out = <RuleLine>[];
    final lines = _text.text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      var l = lines[i].trim();
      if (l.startsWith('- ')) l = l.substring(2).trim();
      if (l.isEmpty || l.startsWith('#')) continue;
      final r = RuleLine.parse(l);
      if (r == null) {
        setState(() => _saveError = s.ruleInvalid(i + 1, l));
        return false;
      }
      out.add(r);
    }
    _rules = out;
    _textMode = false;
    _saveError = null;
    return true;
  }

  void _toggleText() {
    setState(() {
      if (_textMode) {
        _syncFromText();
      } else {
        _text.text = _rules.map((r) => '- $r').join('\n');
        _textMode = true;
      }
    });
  }

  Future<void> _save() async {
    final s = S.of(context);
    if (!_syncFromText()) return;
    final info = _info!;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final lines = _rules.map((r) => r.toString()).toList();
    // Restoring with nothing added means "no own rules".
    final drop = _reset && lines.join('\n') == (info.replace ? info.rules : const <String>[]).join('\n');
    final err = await widget.state.saveRules(widget.subId, drop ? null : lines, replace: info.replace);
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      setState(() => _saveError = s.errorPrefix(err));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.rulesSaved)));
    Navigator.of(context).pop();
  }

  Future<void> _editAt(int index) async {
    final s = S.of(context);
    final r = _rules[index];
    final payload = TextEditingController(text: r.payload);
    final target = TextEditingController(text: r.target);
    var type = r.type;
    var noResolve = r.noResolve;
    final res = await showDialog<RuleLine>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(s.rulesEdit),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _typeField(type, (v) => setD(() => type = v)),
              const SizedBox(height: 10),
              if (type != 'MATCH')
                TextField(
                  controller: payload,
                  decoration: InputDecoration(labelText: s.rulePayload, hintText: _hint(type)),
                ),
              const SizedBox(height: 10),
              _targetField(target),
              if (RuleLine(type: type, target: '').canNoResolve)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: noResolve,
                  title: const Text('no-resolve'),
                  onChanged: (v) => setD(() => noResolve = v ?? false),
                ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
            FilledButton(
              onPressed: () => Navigator.pop(
                  ctx,
                  RuleLine(
                      type: type, payload: payload.text.trim(), target: target.text.trim(), noResolve: noResolve)),
              child: Text(s.save),
            ),
          ],
        ),
      ),
    );
    if (res != null && (res.type == 'MATCH' || res.payload.isNotEmpty) && res.target.isNotEmpty) {
      setState(() => _rules[index] = res);
    }
  }

  Widget _typeField(String value, ValueChanged<String> onChanged) {
    final s = S.of(context);
    final types = _info?.types ?? const ['DOMAIN-SUFFIX'];
    return DropdownButtonFormField<String>(
      initialValue: types.contains(value) ? value : types.first,
      decoration: InputDecoration(labelText: s.ruleType),
      items: [for (final t in types) DropdownMenuItem(value: t, child: Text(t))],
      onChanged: (v) => onChanged(v ?? value),
    );
  }

  Widget _targetField(TextEditingController ctrl) {
    final s = S.of(context);
    final targets = ['DIRECT', 'REJECT', ...?_info?.targets];
    return LayoutBuilder(
      builder: (context, c) => DropdownMenu<String>(
        controller: ctrl,
        width: c.maxWidth,
        enableFilter: true,
        requestFocusOnTap: true,
        menuHeight: 320,
        label: Text(s.ruleTarget),
        dropdownMenuEntries: [for (final t in targets) DropdownMenuEntry(value: t, label: t)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = context.palette;
    final sub = _sub;
    final info = _info;

    Widget body;
    if (_loadError != null) {
      body = Center(child: Text(s.errorPrefix(_loadError!), style: TextStyle(color: p.danger)));
    } else if (info == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 900;
        final form = _form(context);
        final list = _listPane(context, info);
        return wide
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 380, child: SingleChildScrollView(child: form)),
                const SizedBox(width: 20),
                Expanded(child: list),
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                form,
                const SizedBox(height: 12),
                Expanded(child: list),
              ]);
      });
    }

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
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
        if (leave == true && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(s.rulesEditorTitle(sub?.name ?? ''), overflow: TextOverflow.ellipsis)),
        body: Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 8), child: body),
        bottomNavigationBar: info == null
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Row(children: [
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _textMode = false;
                        _reset = true;
                        _rules = [for (final l in (info.replace ? info.rules : const <String>[])) ?RuleLine.parse(l)];
                      }),
                      icon: const Icon(Icons.restore, size: 18),
                      label: Text(s.resetRules),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(_saveError ?? '',
                          maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.danger, fontSize: 13)),
                    ),
                    TextButton(onPressed: () => Navigator.of(context).maybePop(), child: Text(s.cancel)),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(s.save),
                    ),
                  ]),
                ),
              ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final s = S.of(context);
    final p = context.palette;
    final info = _info!;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(info.replace ? s.rulesHintReplace : s.rulesHintPrepend, style: TextStyle(fontSize: 12, color: p.muted)),
      const SizedBox(height: 12),
      _typeField(_type, (v) => setState(() => _type = v)),
      const SizedBox(height: 10),
      if (_type != 'MATCH')
        TextField(
          controller: _payload,
          decoration: InputDecoration(labelText: s.rulePayload, hintText: _hint(_type), errorText: _formError),
          onChanged: (_) {
            if (_formError != null) setState(() => _formError = null);
          },
          onSubmitted: (_) => _add(top: true),
        ),
      const SizedBox(height: 10),
      _targetField(_target),
      if (RuleLine(type: _type, target: '').canNoResolve)
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          value: _noResolve,
          title: const Text('no-resolve'),
          onChanged: (v) => setState(() => _noResolve = v ?? false),
        ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: () => _add(top: true),
            icon: const Icon(Icons.vertical_align_top, size: 18),
            label: Text(s.addTop),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _add(top: false),
            icon: const Icon(Icons.vertical_align_bottom, size: 18),
            label: Text(s.addBottom),
          ),
        ),
      ]),
    ]);
  }

  Widget _listPane(BuildContext context, ProfileRulesInfo info) {
    final s = S.of(context);
    final p = context.palette;
    final filtering = _search.isNotEmpty;
    final visible = <int>[
      for (var i = 0; i < _rules.length; i++)
        if (!filtering || _rules[i].toString().toLowerCase().contains(_search)) i,
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Text(info.replace ? s.rulesOfProfile : s.rulesBadge,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        const SizedBox(width: 8),
        CountBadge(_rules.length),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            enabled: !_textMode,
            decoration: InputDecoration(hintText: s.searchRules, prefixIcon: const Icon(Icons.search, size: 18)),
            onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
          ),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: _toggleText,
          icon: Icon(_textMode ? Icons.view_list_outlined : Icons.code, size: 18),
          label: Text(_textMode ? s.asList : s.asText),
        ),
      ]),
      const SizedBox(height: 8),
      Expanded(
        child: _textMode
            ? TextField(
                controller: _text,
                expands: true,
                maxLines: null,
                minLines: null,
                textAlignVertical: TextAlignVertical.top,
                style: _mono,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              )
            : ReorderableListView.builder(
                buildDefaultDragHandles: false,
                itemCount: visible.length,
                onReorderItem: (from, to) {
                  if (filtering) return;
                  setState(() {
                    final r = _rules.removeAt(from);
                    _rules.insert(to, r);
                  });
                },
                itemBuilder: (context, vi) {
                  final i = visible[vi];
                  final r = _rules[i];
                  return Padding(
                    key: ValueKey('$i:$r'),
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Row(children: [
                          if (!filtering)
                            ReorderableDragStartListener(
                              index: vi,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Icon(Icons.drag_indicator, size: 18, color: p.muted),
                              ),
                            )
                          else
                            const SizedBox(width: 12),
                          SizedBox(width: 132, child: Align(alignment: Alignment.centerLeft, child: CountBadge.label(r.type))),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(r.type == 'MATCH' ? '*' : r.payload,
                                  style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
                              Row(children: [
                                Flexible(
                                  child: Text(r.target,
                                      style: TextStyle(fontSize: 12, color: _targetColor(p, r.target) ?? p.muted),
                                      overflow: TextOverflow.ellipsis),
                                ),
                                if (r.noResolve && r.canNoResolve) ...[
                                  const SizedBox(width: 6),
                                  Text('no-resolve', style: TextStyle(fontSize: 11, color: p.muted)),
                                ],
                              ]),
                            ]),
                          ),
                          IconButton(
                            tooltip: s.rulesEdit,
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => _editAt(i),
                          ),
                          IconButton(
                            tooltip: s.delete,
                            icon: Icon(Icons.delete_outline, size: 18, color: p.danger),
                            onPressed: () => setState(() => _rules.removeAt(i)),
                          ),
                        ]),
                      ),
                    ),
                  );
                },
              ),
      ),
      if (!info.replace && info.readOnly.isNotEmpty)
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(s.profileRulesReadonly, style: const TextStyle(fontSize: 14)),
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView(shrinkWrap: true, children: [
                for (final l in info.readOnly)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(l, style: _mono.copyWith(fontSize: 12, color: p.muted)),
                  ),
              ]),
            ),
          ],
        ),
    ]);
  }
}
