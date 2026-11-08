import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models.dart';
import '../theme.dart';

/// Small colored label naming a core.
class CoreChip extends StatelessWidget {
  const CoreChip(this.core, {super.key, this.auto = false});
  final CoreKind core;
  final bool auto;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (bg, fg) = switch (core) {
      CoreKind.singBox => (p.singBoxBg, p.singBoxFg),
      CoreKind.mihomo => (p.mihomoBg, p.mihomoFg),
    };
    final text = auto ? S.of(context).coreAutoChip(core.label) : core.label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(fontSize: 12, color: fg, height: 1.4)),
    );
  }
}

/// Latency label colored by quality.
class LatencyText extends StatelessWidget {
  const LatencyText(this.node, {super.key, this.style});
  final ProxyNode node;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = context.palette;
    if (node.measuring) {
      return const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 1.5));
    }
    final d = node.delayMs;
    final (text, color) = node.timedOut
        ? (s.pingTimeout, p.danger)
        : d == null
            ? (s.pingUnknown, p.muted)
            : (s.pingMs(d), d < 250 ? p.success : (d < 600 ? p.warning : p.danger));
    return Text(text, style: (style ?? const TextStyle(fontSize: 13)).copyWith(color: color));
  }
}

/// Flat tile on the panel color: label above, value below.
class MetricTile extends StatelessWidget {
  const MetricTile({super.key, required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: p.panel, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: p.muted)),
          const SizedBox(height: 2),
          DefaultTextStyle.merge(style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500), child: child),
        ],
      ),
    );
  }
}

class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: p.warning.withValues(alpha: 0.5), width: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Icon(Icons.science_outlined, size: 16, color: p.warning),
        const SizedBox(width: 8),
        Expanded(child: Text(S.of(context).demoBanner, style: TextStyle(fontSize: 12, color: p.warning))),
      ]),
    );
  }
}

/// Screen title row used by every section.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500))),
        ?trailing,
      ]),
    );
  }
}

String formatGb(BuildContext context, double v) {
  final locale = Localizations.localeOf(context).toString();
  return S.of(context).gb(NumberFormat('#,##0.#', locale).format(v));
}

String formatDate(BuildContext context, DateTime d) =>
    DateFormat.yMd(Localizations.localeOf(context).toString()).format(d);

String formatDuration(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
}

/// 1536 -> "1.5 KB" (or "1,5 КБ" in Russian).
String formatBytes(BuildContext context, int bytes) {
  final ru = Localizations.localeOf(context).languageCode == 'ru';
  final units = ru ? const ['Б', 'КБ', 'МБ', 'ГБ', 'ТБ'] : const ['B', 'KB', 'MB', 'GB', 'TB'];
  var v = bytes.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  final text = i == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(v >= 100 ? 0 : (v >= 10 ? 1 : 2));
  return '${ru ? text.replaceAll('.', ',') : text} ${units[i]}';
}

String timeAgo(BuildContext context, DateTime? t) {
  if (t == null) return '';
  final s = S.of(context);
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return s.secondsAgo(d.inSeconds.clamp(0, 59));
  if (d.inHours < 1) return s.minutesAgo(d.inMinutes);
  return s.hoursAgo(d.inHours);
}

String formatDateTime(BuildContext context, DateTime t) =>
    DateFormat.yMd(Localizations.localeOf(context).toString()).add_Hms().format(t);

/// Colored letter tile standing in for an application icon.
class AppAvatar extends StatelessWidget {
  const AppAvatar(this.name, {super.key, this.size = 36});
  final String name;
  final double size;

  static const _hues = [210.0, 160.0, 30.0, 280.0, 340.0, 190.0, 50.0, 120.0, 250.0, 0.0];

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hue = _hues[name.toLowerCase().codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0x7fffffff) % _hues.length];
    final bg = HSLColor.fromAHSL(1, hue, 0.45, dark ? 0.28 : 0.88).toColor();
    final fg = HSLColor.fromAHSL(1, hue, 0.6, dark ? 0.85 : 0.3).toColor();
    final letter = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size / 4)),
      child: Text(letter, style: TextStyle(color: fg, fontWeight: FontWeight.w500, fontSize: size * 0.45)),
    );
  }
}

/// Small rounded counter or label.
class CountBadge extends StatelessWidget {
  const CountBadge(int count, {super.key, this.color, this.tooltip}) : text = '$count';
  const CountBadge.label(this.text, {super.key, this.color}) : tooltip = null;
  final String text;
  final Color? color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = color;
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: c?.withValues(alpha: 0.18),
        border: Border.all(color: c ?? p.hairline, width: 0.8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: c ?? p.muted, fontWeight: FontWeight.w500)),
    );
    return tooltip == null ? badge : Tooltip(message: tooltip!, child: badge);
  }
}
