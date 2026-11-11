import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import '../l10n/app_localizations.dart';
import '../core/android_backend.dart';
import '../core/open_url.dart';
import '../desktop.dart';
import '../models.dart';
import '../state/scope.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'settings_advanced.dart';

const appVersion = '0.3.2';
const singBoxVersion = '1.14.4';
const mihomoVersion = '1.19.33';
const repoUrl = 'https://github.com/sola21/solahelm-client';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = AppScope.of(context);
    final settings = st.settings;
    final p = context.palette;

    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Text(t, style: TextStyle(fontSize: 13, color: p.muted)),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        SectionHeader(s.navSettings),
        label(s.settingsUiMode),
        SegmentedButton<UiMode>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: UiMode.simple, label: Text(s.uiSimple), icon: const Icon(Icons.power_settings_new, size: 18)),
            ButtonSegment(value: UiMode.advanced, label: Text(s.uiAdvanced), icon: const Icon(Icons.tune, size: 18)),
          ],
          selected: {settings.uiMode ?? UiMode.advanced},
          onSelectionChanged: (v) => settings.setUiMode(v.first),
        ),
        const SizedBox(height: 8),
        Text(settings.simple ? s.uiSimpleHint : s.uiAdvancedHint, style: TextStyle(fontSize: 12, color: p.muted, height: 1.4)),
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
        if (!settings.simple) ...[
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
        ],
        label(s.settingsRouting),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: CoreSettings.routingRuDirect, label: Text(s.routingRuDirect)),
            ButtonSegment(value: CoreSettings.routingAll, label: Text(s.routingAll)),
          ],
          selected: {settings.core.linkRouting},
          onSelectionChanged: (v) => settings.setCore(settings.core.copyWith(linkRouting: v.first)),
        ),
        const SizedBox(height: 8),
        Text(s.routingHint, style: TextStyle(fontSize: 12, color: p.muted, height: 1.4)),
        label(s.secDns),
        Card(
          child: DnsModeTile(
            cs: settings.core,
            simple: settings.simple,
            onChanged: (m) => settings.setCore(settings.core.copyWith(dnsMode: m)),
          ),
        ),
        label(s.settingsExit),
        Card(
          child: SwitchListTile(
            secondary: const Icon(Icons.public),
            title: Text(s.showExitInfo),
            subtitle: Text(s.showExitInfoHint, style: TextStyle(fontSize: 12, color: p.muted)),
            value: settings.showExitInfo,
            onChanged: st.setShowExitInfo,
          ),
        ),
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
              ListTile(
                dense: true,
                title: Text(s.toggleHotkey),
                subtitle: Text(settings.toggleHotkey == null ? s.hotkeyNone : hotkeyLabel(settings.toggleHotkey!)),
                trailing: Wrap(spacing: 4, children: [
                  if (settings.toggleHotkey != null)
                    IconButton(
                      tooltip: s.delete,
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => settings.setToggleHotkey(null),
                    ),
                  OutlinedButton(onPressed: () => _recordHotkey(context, settings), child: Text(s.hotkeySet)),
                ]),
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
        if (Platform.isAndroid) ...[
          label(s.settingsAndroid),
          Card(
            child: Column(children: [
              SwitchListTile(
                secondary: const Icon(Icons.notifications_outlined),
                title: Text(s.vpnNotification),
                subtitle: Text(s.vpnNotificationHint, style: TextStyle(fontSize: 12, color: p.muted)),
                value: settings.vpnNotification,
                onChanged: settings.setVpnNotification,
              ),
              if (!settings.vpnNotification) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.notifications_off_outlined),
                  title: Text(s.vpnNotificationHide),
                  subtitle: Text(s.vpnNotificationHideHint, style: TextStyle(fontSize: 12, color: p.muted)),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => AndroidBridge.openNotificationSettings().catchError((_) {}),
                ),
              ],
              const Divider(),
              ListTile(
                leading: const Icon(Icons.toggle_on_outlined),
                title: Text(s.quickTile),
                subtitle: Text(s.quickTileHint, style: TextStyle(fontSize: 12, color: p.muted)),
              ),
            ]),
          ),
        ],
        if (!settings.simple) label(s.settingsConnection),
        if (!settings.simple) Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.lan_outlined),
              title: Text(s.settingsConnection),
              subtitle: Text(s.settingsConnectionHint),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => ConnectionSettingsPage.open(context, AppScope.of(context)),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.memory_outlined),
              title: Text(s.settingsCoreAdv),
              subtitle: Text(s.settingsCoreAdvHint),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => CoreSettingsPage.open(context, AppScope.of(context)),
            ),
          ]),
        ),
        if (st.updater != null) ...[
          label(s.updates),
          const _UpdatesCard(),
        ],
        label(s.settingsAbout),
        Text('SolaHelm Client $appVersion${isPortable ? ' · portable' : ''}', style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 2),
        Text(s.coreVersions(singBoxVersion, mihomoVersion), style: TextStyle(fontSize: 12, color: p.muted)),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4), visualDensity: VisualDensity.compact),
            onPressed: () => openUrl(repoUrl).catchError((_) {}),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('github.com/sola21/solahelm-client'),
          ),
        ),
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

/// "Ctrl + Alt + V" from hotkey_manager JSON.
String hotkeyLabel(Map<String, dynamic> json) {
  try {
    final hk = HotKey.fromJson(json);
    final mods = [for (final m in hk.modifiers ?? const <HotKeyModifier>[]) m.physicalKeys.first.debugName ?? m.name];
    return [...mods, hk.key.keyLabel].join(' + ');
  } catch (_) {
    return '?';
  }
}

Future<void> _recordHotkey(BuildContext context, Settings settings) async {
  final s = S.of(context);
  HotKey? recorded;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: Text(s.toggleHotkey),
        content: SizedBox(
          width: 380,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.hotkeyPress),
            const SizedBox(height: 16),
            HotKeyRecorder(onHotKeyRecorded: (hk) => setD(() => recorded = hk)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          FilledButton(onPressed: recorded == null ? null : () => Navigator.pop(ctx, true), child: Text(s.save)),
        ],
      ),
    ),
  );
  if (ok == true && recorded != null) settings.setToggleHotkey(recorded!.toJson());
}

class _UpdatesCard extends StatelessWidget {
  const _UpdatesCard();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = AppScope.of(context);
    final p = context.palette;
    final upd = st.update;
    final status = switch (st.updateStatus) {
      null => '',
      'latest' => s.updateLatest,
      'none' => s.updateNoReleases,
      final e => s.errorPrefix(e),
    };
    return Card(
      child: Column(children: [
        SwitchListTile(
          dense: true,
          title: Text(s.checkUpdates),
          value: st.settings.checkUpdates,
          onChanged: st.settings.setCheckUpdates,
        ),
        const Divider(),
        ListTile(
          dense: true,
          title: Text(upd != null ? s.updateAvailable(upd.version) : (status.isEmpty ? 'SolaHelm Client $appVersion' : status)),
          subtitle: st.updateProgress != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    LinearProgressIndicator(value: st.updateProgress),
                    const SizedBox(height: 4),
                    Text(s.updateDownloading((st.updateProgress! * 100).round()), style: TextStyle(fontSize: 12, color: p.muted)),
                  ]),
                )
              : (upd != null ? Text(s.updateHint, style: TextStyle(fontSize: 12, color: p.muted)) : null),
          trailing: upd != null
              ? FilledButton(
                  onPressed: st.updateProgress != null ? null : () => DesktopShell.instance?.installUpdateAndExit(),
                  child: Text(s.updateTo(upd.version)),
                )
              : OutlinedButton(
                  onPressed: st.checkingUpdate ? null : () => st.checkForUpdates(),
                  child: st.checkingUpdate
                      ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(s.checkNow),
                ),
        ),
        if (upd != null && upd.notes.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(upd.notes.trim(), maxLines: 8, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: p.muted)),
            ),
          ),
      ]),
    );
  }
}
