import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import '../state/scope.dart';
import '../state/settings.dart';
import '../theme.dart';
import 'settings.dart' show singBoxVersion, mihomoVersion;

/// Shown on the advanced pages while connected with older settings.
class ReapplyBanner extends StatelessWidget {
  const ReapplyBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    if (!st.needsReapply) return const SizedBox.shrink();
    final s = S.of(context);
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        border: Border.all(color: p.warning.withValues(alpha: 0.6), width: 0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Icon(Icons.info_outline, size: 18, color: p.warning),
        const SizedBox(width: 8),
        Expanded(child: Text(s.reapplyHint, style: TextStyle(fontSize: 13, color: p.warning))),
        FilledButton.tonal(onPressed: st.status.busy ? null : st.reconnect, child: Text(s.reapply)),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.children);
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(title, style: TextStyle(fontSize: 13, color: p.muted, fontWeight: FontWeight.w500)),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ),
      ]),
    );
  }
}

Widget _hint(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Text(text, style: TextStyle(fontSize: 12, color: context.palette.muted, height: 1.35)),
    );

/// A number with validation; saves on submit or focus loss.
class _NumberField extends StatefulWidget {
  const _NumberField({required this.value, required this.min, required this.max, required this.error, required this.onChanged});
  final int value, min, max;
  final String error;
  final ValueChanged<int> onChanged;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final _ctrl = TextEditingController(text: '${widget.value}');
  final _focus = FocusNode();
  String? _err;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit() {
    final v = int.tryParse(_ctrl.text.trim());
    if (v == null || v < widget.min || v > widget.max) {
      setState(() => _err = widget.error);
      return;
    }
    setState(() => _err = null);
    if (v != widget.value) widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 130,
        child: TextField(
          controller: _ctrl,
          focusNode: _focus,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(errorText: _err, errorMaxLines: 2),
          onSubmitted: (_) => _commit(),
        ),
      );
}

/// Editable list of strings: delete per item, add with validation.
class _StringListEditor extends StatefulWidget {
  const _StringListEditor({
    required this.items,
    required this.onChanged,
    required this.addLabel,
    required this.hint,
    this.validate,
    this.defaults,
    this.defaultsLabel,
  });
  final List<String> items;
  final ValueChanged<List<String>> onChanged;
  final String addLabel, hint;
  final String? Function(String)? validate;
  final List<String>? defaults;
  final String? defaultsLabel;

  @override
  State<_StringListEditor> createState() => _StringListEditorState();
}

class _StringListEditorState extends State<_StringListEditor> {
  final _ctrl = TextEditingController();
  String? _err;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _add() {
    final v = _ctrl.text.trim();
    if (v.isEmpty) return;
    final e = widget.validate?.call(v);
    if (e != null) {
      setState(() => _err = e);
      return;
    }
    setState(() => _err = null);
    if (!widget.items.contains(v)) widget.onChanged([...widget.items, v]);
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final item in widget.items)
            InputChip(
              label: Text(item, style: const TextStyle(fontSize: 13)),
              onDeleted: () => widget.onChanged(widget.items.where((e) => e != item).toList()),
              deleteIconColor: p.danger,
            ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              decoration: InputDecoration(hintText: widget.hint, errorText: _err),
              onChanged: (_) {
                if (_err != null) setState(() => _err = null);
              },
              onSubmitted: (_) => _add(),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(onPressed: _add, icon: const Icon(Icons.add, size: 18), label: Text(widget.addLabel)),
          if (widget.defaults != null) ...[
            const SizedBox(width: 8),
            TextButton(onPressed: () => widget.onChanged([...widget.defaults!]), child: Text(widget.defaultsLabel ?? '')),
          ],
        ]),
      ]),
    );
  }
}

bool _validCidr(String v) {
  final parts = v.split('/');
  if (parts.length != 2) return false;
  final bits = int.tryParse(parts[1]);
  final ip = InternetAddress.tryParse(parts[0]);
  if (ip == null || bits == null) return false;
  return bits >= 0 && bits <= (ip.type == InternetAddressType.IPv4 ? 32 : 128);
}

/// The reconnect banner stays pinned above the scrolling settings.
/// A plain IP, or a URL-like resolver (https://, tls://, quic://, udp://, tcp://).
bool _validResolver(String v) {
  if (InternetAddress.tryParse(v) != null) return true;
  final u = Uri.tryParse(v);
  return u != null && const {'https', 'tls', 'quic', 'udp', 'tcp'}.contains(u.scheme) && u.host.isNotEmpty;
}

Scaffold _page(BuildContext context, String title, List<Widget> children) => Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 0), child: ReapplyBanner()),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: children),
        ),
      ]),
    );

/// TUN, system proxy and ports.
class ConnectionSettingsPage extends StatelessWidget {
  const ConnectionSettingsPage({super.key});

  static Future<void> open(BuildContext context, AppState st) => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => AppScope(state: st, child: const ConnectionSettingsPage()),
      ));

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = AppScope.of(context);
    final settings = st.settings;
    final cs = settings.core;
    void set(CoreSettings v) => settings.setCore(v);

    return _page(context, s.settingsConnection, [
      _Section(s.secTun, [
        SwitchListTile(
          title: Text(s.manageTun),
          subtitle: cs.manageTun ? null : Text(s.manageTunOff),
          value: cs.manageTun,
          onChanged: (v) => set(cs.copyWith(manageTun: v)),
        ),
        if (cs.manageTun) ...[
          const Divider(),
          ListTile(
            title: Text(s.tunStack),
            trailing: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'gvisor', label: Text('gVisor')),
                ButtonSegment(value: 'mixed', label: Text('Mixed')),
                ButtonSegment(value: 'system', label: Text('System')),
              ],
              selected: {cs.tunStack},
              onSelectionChanged: (v) => set(cs.copyWith(tunStack: v.first)),
            ),
          ),
          _hint(context, s.tunStackHint),
          const Divider(),
          SwitchListTile(
            title: Text(s.strictRoute),
            subtitle: Text(s.strictRouteHint),
            value: cs.strictRoute,
            onChanged: (v) => set(cs.copyWith(strictRoute: v)),
          ),
          const Divider(),
          ListTile(
            title: Text(s.mtu),
            trailing: _NumberField(
              value: cs.mtu,
              min: 576,
              max: 65535,
              error: s.invalidMtu,
              onChanged: (v) => set(cs.copyWith(mtu: v)),
            ),
          ),
          const Divider(),
          ListTile(title: Text(s.routeExclude)),
          _hint(context, s.routeExcludeHint),
          _StringListEditor(
            items: cs.routeExclude,
            onChanged: (v) => set(cs.copyWith(routeExclude: v)),
            addLabel: s.addNetwork,
            hint: s.networkHint,
            validate: (v) => _validCidr(v) ? null : s.invalidCidr,
            defaults: CoreSettings.defaultRouteExclude,
            defaultsLabel: s.restoreDefaults,
          ),
        ],
      ]),
      _Section(s.secSysProxy, [
        ListTile(title: Text(s.proxyBypass)),
        _hint(context, s.proxyBypassHint),
        _StringListEditor(
          items: cs.proxyBypass,
          onChanged: (v) => set(cs.copyWith(proxyBypass: v)),
          addLabel: s.addException,
          hint: '*.example.com',
          validate: (v) => v.contains(';') || v.contains(' ') ? s.ruleInvalid(0, v) : null,
          defaults: CoreSettings.defaultProxyBypass,
          defaultsLabel: s.restoreDefaults,
        ),
      ]),
      _Section(s.secPorts, [
        ListTile(
          title: Text(s.mixedPort),
          subtitle: Text(s.mixedPortHint),
          trailing: _NumberField(
            value: cs.mixedPort,
            min: 1,
            max: 65535,
            error: s.invalidPort,
            onChanged: (v) => set(cs.copyWith(mixedPort: v)),
          ),
        ),
        const Divider(),
        SwitchListTile(
          title: Text(s.allowLan),
          subtitle: Text(s.allowLanHint),
          value: cs.allowLan,
          onChanged: (v) => set(cs.copyWith(allowLan: v)),
        ),
        if (cs.allowLan) const _LanAddresses(),
      ]),
    ]);
  }
}

class _LanAddresses extends StatelessWidget {
  const _LanAddresses();

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final port = st.coreStatus.port ?? st.settings.core.mixedPort;
    return FutureBuilder<List<NetworkInterface>>(
      future: NetworkInterface.list(type: InternetAddressType.IPv4),
      builder: (context, snap) {
        final ips = [
          for (final i in snap.data ?? const <NetworkInterface>[])
            for (final a in i.addresses)
              if (!a.isLoopback && !a.isLinkLocal) '${a.address}:$port',
        ];
        if (ips.isEmpty) return const SizedBox.shrink();
        return _hint(context, S.of(context).lanAddresses(ips.join(', ')));
      },
    );
  }
}

/// IPv6, log level, process detection, versions.
class CoreSettingsPage extends StatelessWidget {
  const CoreSettingsPage({super.key});

  static Future<void> open(BuildContext context, AppState st) => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => AppScope(state: st, child: const CoreSettingsPage()),
      ));

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = AppScope.of(context);
    final settings = st.settings;
    final cs = settings.core;
    void set(CoreSettings v) => settings.setCore(v);
    final versions = st.coreStatus.versions;

    return _page(context, s.settingsCoreAdv, [
      _Section(s.settingsCoreAdv, [
        ListTile(
          title: Text(s.ipv6),
          trailing: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 'profile', label: Text(s.ipv6Profile)),
              ButtonSegment(value: 'on', label: Text(s.ipv6On)),
              ButtonSegment(value: 'off', label: Text(s.ipv6Off)),
            ],
            selected: {cs.ipv6},
            onSelectionChanged: (v) => set(cs.copyWith(ipv6: v.first)),
          ),
        ),
        const Divider(),
        ListTile(
          title: Text(s.logLevel),
          trailing: DropdownButton<String>(
            value: cs.logLevel,
            underline: const SizedBox.shrink(),
            items: [
              DropdownMenuItem(value: '', child: Text(s.logLevelProfile)),
              for (final l in const ['debug', 'info', 'warning', 'error', 'silent'])
                DropdownMenuItem(value: l, child: Text(l)),
            ],
            onChanged: (v) => set(cs.copyWith(logLevel: v ?? '')),
          ),
        ),
        const Divider(),
        SwitchListTile(
          title: Text(s.findProcess),
          subtitle: Text(s.findProcessHint),
          value: cs.findProcess,
          onChanged: (v) => set(cs.copyWith(findProcess: v)),
        ),
      ]),
      _Section(s.secDns, [
        SwitchListTile(
          title: Text(s.dnsOverride),
          subtitle: Text(s.dnsOverrideHint),
          value: cs.dnsOverride,
          onChanged: (v) => set(cs.copyWith(dnsOverride: v)),
        ),
        if (cs.dnsOverride) ...[
          const Divider(),
          ListTile(title: Text(s.dnsRemote)),
          _hint(context, s.dnsRemoteHint),
          _StringListEditor(
            items: cs.dnsRemote,
            onChanged: (v) => set(cs.copyWith(dnsRemote: v)),
            addLabel: s.add,
            hint: 'https://dns.google/dns-query',
            validate: (v) => _validResolver(v) ? null : s.invalidResolver,
            defaults: CoreSettings.defaultDnsRemote,
            defaultsLabel: s.restoreDefaults,
          ),
          const Divider(),
          ListTile(title: Text(s.dnsDirect)),
          _hint(context, s.dnsDirectHint),
          _StringListEditor(
            items: cs.dnsDirect,
            onChanged: (v) => set(cs.copyWith(dnsDirect: v)),
            addLabel: s.add,
            hint: '77.88.8.8',
            validate: (v) => _validResolver(v) ? null : s.invalidResolver,
            defaults: CoreSettings.defaultDnsDirect,
            defaultsLabel: s.restoreDefaults,
          ),
        ],
      ]),
      _Section(s.settingsAbout, [
        ListTile(
          title: const Text('sing-box'),
          trailing: Text(versions['sing-box'] ?? singBoxVersion),
        ),
        const Divider(),
        ListTile(
          title: const Text('mihomo'),
          trailing: Text(versions['mihomo'] ?? mihomoVersion),
        ),
        _hint(context, s.coresBuiltIn),
      ]),
    ]);
  }
}
