import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models.dart';
import '../state/scope.dart';
import '../theme.dart';
import '../widgets/common.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  String _level = ''; // '' = all
  String _query = '';
  final _scroll = ScrollController();

  static const _levels = ['debug', 'info', 'warning', 'error'];

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool _match(LogEntry e) {
    if (_level.isNotEmpty) {
      final want = _levels.indexOf(_level);
      final got = _levels.indexOf(_norm(e.level));
      if (got >= 0 && got < want) return false;
    }
    return _query.isEmpty || e.message.toLowerCase().contains(_query);
  }

  static String _norm(String l) => switch (l.toLowerCase()) {
        'warn' => 'warning',
        'fatal' || 'panic' => 'error',
        'trace' => 'debug',
        final x => x,
      };

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = AppScope.of(context);
    final p = context.palette;
    final items = st.logs.where(_match).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionHeader(
          s.navLogs,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              tooltip: st.logsPaused ? s.resume : s.pause,
              icon: Icon(st.logsPaused ? Icons.play_arrow : Icons.pause),
              onPressed: () => st.setLogsPaused(!st.logsPaused),
            ),
            IconButton(
              tooltip: s.copy,
              icon: const Icon(Icons.copy_all_outlined),
              onPressed: items.isEmpty
                  ? null
                  : () {
                      Clipboard.setData(ClipboardData(
                          text: items.map((e) => '${_time(e.time)} ${e.level.toUpperCase()} ${e.message}').join('\n')));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.copied)));
                    },
            ),
            IconButton(tooltip: s.clear, icon: const Icon(Icons.delete_sweep_outlined), onPressed: st.clearLogs),
          ]),
        ),
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(
            width: 260,
            child: TextField(
              decoration: InputDecoration(hintText: s.search, prefixIcon: const Icon(Icons.search, size: 18)),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          for (final l in ['', ..._levels])
            ChoiceChip(
              label: Text(l.isEmpty ? s.levelAll : l),
              selected: _level == l,
              onSelected: (_) => setState(() => _level = l),
            ),
        ]),
        const SizedBox(height: 8),
        Expanded(
          child: items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: Text(s.logsEmpty, textAlign: TextAlign.center, style: TextStyle(color: p.muted)),
                )
              : SelectionArea(
                  child: ListView.builder(
                    controller: _scroll,
                    reverse: true, // newest at the bottom, list sticks to it
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final e = items[items.length - 1 - i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(text: '${_time(e.time)} ', style: TextStyle(color: p.muted)),
                            TextSpan(
                              text: '${_norm(e.level).toUpperCase().padRight(7)} ',
                              style: TextStyle(color: _color(p, e.level), fontWeight: FontWeight.w500),
                            ),
                            TextSpan(text: e.message),
                          ]),
                          style: const TextStyle(
                            fontFamily: 'Consolas',
                            fontFamilyFallback: ['Menlo', 'DejaVu Sans Mono', 'monospace'],
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ]),
    );
  }

  static String _time(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

  static Color _color(AppPalette p, String level) => switch (_norm(level)) {
        'error' => p.danger,
        'warning' => p.warning,
        'debug' => p.muted,
        _ => p.success,
      };
}
