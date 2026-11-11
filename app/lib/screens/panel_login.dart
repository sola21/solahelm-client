import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// What the address field shows as an example.
const panelUrlExample = 'panel.example.org/hy/';

/// Address schemes the field offers; https:// first (http:// is for a panel on this device).
const panelSchemes = ['https://', 'http://'];

/// Splits an address into the scheme from [panelSchemes] and the rest.
(String, String) splitPanelUrl(String url) {
  final t = url.trim();
  for (final sc in panelSchemes) {
    if (t.toLowerCase().startsWith(sc)) return (sc, t.substring(sc.length));
  }
  return (panelSchemes.first, t);
}

/// Text for a PanelException code (see PanelApi).
String panelError(S s, String code) => switch (code) {
      'bad_url' => s.panelErrBadUrl,
      'insecure' => s.panelErrInsecure,
      'network' => s.panelErrNetwork,
      'certificate' => s.panelErrCertificate,
      'not_a_panel' => s.panelErrNotPanel,
      'bad_credentials' => s.panelErrCredentials,
      'rate_limited' => s.panelErrRateLimited,
      'unauthorized' => s.panelErrUnauthorized,
      _ => s.panelErrOther(code),
    };

/// Sign in to a SolaHelm panel with the cabinet's login and password.
/// Completes with true once signed in.
Future<bool> showPanelLoginDialog(BuildContext context, AppState st,
    {String? url, String? login, bool selfSigned = false}) async {
  final messenger = ScaffoldMessenger.of(context);
  final s = S.of(context);
  final added = await showDialog<int>(
    context: context,
    builder: (_) => _PanelLoginDialog(state: st, url: url ?? '', login: login ?? '', selfSigned: selfSigned),
  );
  if (added == null) return false;
  messenger.showSnackBar(SnackBar(content: Text(s.panelSignedIn(added))));
  return true;
}

class _PanelLoginDialog extends StatefulWidget {
  const _PanelLoginDialog({required this.state, required this.url, required this.login, required this.selfSigned});
  final AppState state;
  final String url, login;
  final bool selfSigned;

  @override
  State<_PanelLoginDialog> createState() => _PanelLoginDialogState();
}

class _PanelLoginDialogState extends State<_PanelLoginDialog> {
  late String _scheme = splitPanelUrl(widget.url).$1;
  late final _url = TextEditingController(text: splitPanelUrl(widget.url).$2);
  late final _login = TextEditingController(text: widget.login);
  final _password = TextEditingController();
  late bool _selfSigned = widget.selfSigned;
  bool _busy = false;
  bool _hide = true;
  String? _error;

  /// A pasted full address: take its scheme into the list.
  void _onUrlChanged(String v) {
    if (!v.contains('://')) return;
    final (sc, rest) = splitPanelUrl(v);
    if (!v.trim().toLowerCase().startsWith(sc)) return; // some other scheme: let the check report it
    setState(() => _scheme = sc);
    _url.value = TextEditingValue(text: rest, selection: TextSelection.collapsed(offset: rest.length));
  }

  @override
  void dispose() {
    _url.dispose();
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final s = S.of(context);
    if (_url.text.trim().isEmpty) {
      setState(() => _error = s.panelErrNoUrl);
      return;
    }
    if (_login.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = s.panelErrEmpty);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final before = widget.state.subscriptions.length;
    final rest = _url.text.trim();
    final url = rest.contains('://') ? rest : '$_scheme$rest';
    final err = await widget.state.loginPanel(url, _login.text, _password.text, selfSigned: _selfSigned);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _busy = false;
        _error = panelError(s, err);
      });
      return;
    }
    Navigator.of(context).pop(widget.state.subscriptions.length - before);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = context.palette;
    return AlertDialog(
      title: Text(s.panelSignInTitle),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: AutofillGroup(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(s.panelSignInHint, style: TextStyle(fontSize: 13, color: p.muted, height: 1.35)),
              const SizedBox(height: 16),
              TextField(
                controller: _url,
                enabled: !_busy,
                keyboardType: TextInputType.url,
                autocorrect: false,
                onChanged: _onUrlChanged,
                decoration: InputDecoration(
                  labelText: s.panelUrl,
                  hintText: panelUrlExample,
                  prefixIconConstraints: const BoxConstraints(minWidth: 0),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 12, right: 4),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        key: const ValueKey('panelScheme'),
                        value: _scheme,
                        isDense: true,
                        items: [for (final sc in panelSchemes) DropdownMenuItem(value: sc, child: Text(sc))],
                        onChanged: _busy ? null : (v) => setState(() => _scheme = v ?? _scheme),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _login,
                enabled: !_busy,
                autocorrect: false,
                autofillHints: const [AutofillHints.username],
                decoration: InputDecoration(labelText: s.panelLogin, prefixIcon: const Icon(Icons.person_outline)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                enabled: !_busy,
                obscureText: _hide,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _busy ? null : _submit(),
                decoration: InputDecoration(
                  labelText: s.panelPassword,
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _hide = !_hide),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              CheckboxListTile(
                value: _selfSigned,
                onChanged: _busy ? null : (v) => setState(() => _selfSigned = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                title: Text(s.panelSelfSigned),
                subtitle: Text(s.panelSelfSignedHint, style: TextStyle(fontSize: 12, color: p.muted)),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 8),
              Text(s.panelPasswordNotKept, style: TextStyle(fontSize: 12, color: p.muted)),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: Text(s.cancel)),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(s.panelSignIn),
        ),
      ],
    );
  }
}
