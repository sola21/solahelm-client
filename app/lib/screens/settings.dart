import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../desktop.dart';
import '../models.dart';
import '../state/scope.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../widgets/common.dart';

const appVersion = '0.1.0';
const singBoxVersion = '1.14.4';
const mihomoVersion = '1.19.33';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final settings = AppScope.of(context).settings;
    final p = context.palette;

    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Text(t, style: TextStyle(fontSize: 13, color: p.muted)),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        SectionHeader(s.navSettings),
        label(s.settingsTheme),
        SegmentedButton<ThemeMode>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: ThemeMode.system, label: Text(s.themeSystem), icon: const Icon(Icons.brightness_auto_outlined, size: 18)),
            ButtonSegment(value: ThemeMode.light, label: Text(s.themeLight), icon: const Icon(Icons.light_mode_outlined, size: 18)),
            ButtonSegment(value: ThemeMode.dark, label: Text(s.themeDark), icon: const Icon(Icons.dark_mode_outlined, size: 18)),
          ],
          selected: {settings.themeMode},
          onSelectionChanged: (v) => settings.setThemeMode(v.first),
        ),
        label(s.settingsLanguage),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: '', label: Text(s.languageSystem)),
            const ButtonSegment(value: 'ru', label: Text('Русский')),
            const ButtonSegment(value: 'en', label: Text('English')),
          ],
          selected: {settings.languageCode ?? ''},
          onSelectionChanged: (v) => settings.setLanguage(v.first.isEmpty ? null : v.first),
        ),
        label(s.settingsCore),
        SegmentedButton<CorePref>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: CorePref.auto, label: Text(s.coreAuto)),
            ButtonSegment(value: CorePref.singBox, label: Text(CoreKind.singBox.label)),
            ButtonSegment(value: CorePref.mihomo, label: Text(CoreKind.mihomo.label)),
          ],
          selected: {settings.corePref},
          onSelectionChanged: (v) => settings.setCorePref(v.first),
        ),
        const SizedBox(height: 8),
        Text(s.coreHint, style: TextStyle(fontSize: 12, color: p.muted, height: 1.4)),
        if (DesktopShell.supported) ...[
          label(s.settingsBehavior),
          Card(
            child: Column(children: [
              SwitchListTile(
                dense: true,
                title: Text(s.closeToTray),
                value: settings.closeToTray,
                onChanged: settings.setCloseToTray,
              ),
              const Divider(),
              SwitchListTile(
                dense: true,
                title: Text(s.launchAtStartup),
                value: settings.launchAtStartup,
                onChanged: settings.setLaunchAtStartup,
              ),
              const Divider(),
              SwitchListTile(
                dense: true,
                title: Text(s.startMinimized),
                value: settings.startMinimized,
                onChanged: settings.setStartMinimized,
              ),
              const Divider(),
              SwitchListTile(
                dense: true,
                title: Text(s.autoConnect),
                subtitle: settings.proxyMode == ProxyMode.tun
                    ? Text(s.autoConnectTunNote, style: TextStyle(fontSize: 12, color: p.muted))
                    : null,
                value: settings.autoConnect,
                onChanged: settings.setAutoConnect,
              ),
            ]),
          ),
        ],
        label(s.settingsAbout),
        Text('SolaHelm Client $appVersion${isPortable ? ' · portable' : ''}', style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 2),
        Text(s.coreVersions(singBoxVersion, mihomoVersion), style: TextStyle(fontSize: 12, color: p.muted)),
      ],
    );
  }
}

/// Sections that need the core bridge before they can show anything real.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        SectionHeader(title),
        const SizedBox(height: 48),
        Icon(icon, size: 40, color: p.muted),
        const SizedBox(height: 12),
        Text(S.of(context).comingSoon, textAlign: TextAlign.center, style: TextStyle(color: p.muted)),
      ],
    );
  }
}
