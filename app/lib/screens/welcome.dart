import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models.dart';
import '../state/settings.dart';
import '../theme.dart';

/// First start: simple or advanced interface. Can be changed later in Settings.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.settings});

  final Settings settings;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = context.palette;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                Text(s.welcomeTitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Text(s.welcomeSubtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: p.muted)),
                const SizedBox(height: 28),
                _Choice(
                  icon: Icons.power_settings_new,
                  title: s.uiSimple,
                  text: s.uiSimpleHint,
                  primary: true,
                  onTap: () => settings.setUiMode(UiMode.simple),
                ),
                const SizedBox(height: 12),
                _Choice(
                  icon: Icons.tune,
                  title: s.uiAdvanced,
                  text: s.uiAdvancedHint,
                  onTap: () => settings.setUiMode(UiMode.advanced),
                ),
                const SizedBox(height: 20),
                Text(s.welcomeLater, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: p.muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.icon, required this.title, required this.text, required this.onTap, this.primary = false});

  final IconData icon;
  final String title;
  final String text;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = context.palette;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: primary ? scheme.primary : p.hairline, width: primary ? 1.5 : 0.5),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: primary ? scheme.primary : scheme.surfaceContainerHighest,
              foregroundColor: primary ? scheme.onPrimary : scheme.onSurface,
              child: Icon(icon),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(text, style: TextStyle(fontSize: 13, color: p.muted, height: 1.35)),
              ]),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: p.muted),
          ]),
        ),
      ),
    );
  }
}
