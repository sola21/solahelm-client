# SolaHelm Client

A client for Windows and Android (Linux comes next) with **both cores built in — sing-box and mihomo**.
It picks the core from your config by itself. Made first of all for subscriptions from the
[SolaHelm](https://github.com/sola21/solahelm) panel, but accepts any sing-box or Clash Meta config.

Bilingual interface (**English / Русский**), light and dark themes.

> Русская версия: [README.ru.md](README.ru.md)

> **Status: alpha.** Tested on Windows 11 and Android 16; expect rough edges — please report them in Issues.

> **Disclaimer.** Independent community project, not affiliated with sing-box, mihomo, Clash or Hysteria. The
> names of the cores are used only to say which core runs your config. You are responsible for using it in
> compliance with the laws that apply to you.

## Download

Get the latest version from [Releases](https://github.com/sola21/solahelm-client/releases/latest):

| File | For |
|---|---|
| `SolaHelm-<version>-windows-x64-setup.exe` | Windows 10/11 x64, installer: no admin rights, shortcuts, uninstall from Apps |
| `SolaHelm-<version>-windows-x64.zip` | the same without installing, data in `%APPDATA%\solahelm-client` |
| `SolaHelm-<version>-windows-x64-portable.zip` | the same, with all data in a `userdata` folder next to the program |
| `SolaHelm-<version>-android-arm64.apk` | Android 7.0+, almost every phone |
| `SolaHelm-<version>-android-x86_64.apk` | Android emulators and some Chromebooks |

Windows: run the setup.exe, or unzip anywhere and run `solahelm_client.exe`. TUN mode needs administrator rights — the client
asks for them when you connect. After that the client updates itself.

Android: install the APK (allow installs from that source), add a subscription, tap Connect and allow
the VPN.

## Features

- **Simple and advanced modes.** On first start the client asks which you prefer: simple — one button, the
  country and a server list; advanced — everything else. Change it in Settings → Interface.
- **Exit country and IP:** after connecting, the home screen shows the flag and country your traffic comes out
  in, and the IP — masked until tapped (`203.0.*.*`). Looked up from `ipwho.is` through the VPN itself; can be
  turned off in the settings.
- **Two cores in one client:** sing-box 1.14 and mihomo 1.19; the core is picked from the subscription format.
- **Subscriptions:** sing-box JSON, Clash/mihomo YAML and "universal" ones — a list of `hysteria2://`,
  `vless://`, `trojan://`, `tuic://`, `ss://`, `anytls://` … links, plain or base64. Import from a file or the
  clipboard, traffic and expiry from the subscription headers, view and edit the profile with a check by the core.
- **Sign in to a SolaHelm panel** with the client cabinet's login and password (panel 1.15+): all the client's
  profiles are added as subscriptions and kept up to date; the password isn't stored — the panel gives the app its
  own key, which can be revoked in the cabinet. Panels with a self-signed certificate work after an explicit
  confirmation.
- **QR codes:** on Windows from the screen (every display) or a picture, on Android with the camera or from
  the gallery; a subscription link opens the add dialog, server links become a profile.
- **Modes:** TUN (all traffic of the device), system proxy (Windows), local port only.
- **Nodes:** groups, latency, node selection, routing mode (rules / global / direct).
- **Rules:** your own Clash-syntax list on top of the profile that survives subscription updates; a quick
  rule from a connection's card.
- **Connections** grouped by process (Windows) or app (Android), closing connections; the core's **log**.
- **Windows:** tray menu (connect, mode, nodes, subscriptions), close to tray, start with Windows, start
  minimized, a hotkey to toggle the VPN, exit while keeping the VPN on, auto-update, portable build.
- **Android:** a quick-settings tile (VPN on/off without opening the app), a foldable notification.
- **Settings on top of the profile:** TUN stack, strict route, MTU, networks that bypass the tunnel, system
  proxy exceptions, port, LAN access, IPv6, log level, DNS mode.

## How it works

```
┌──────────────── Flutter UI (app/) ────────────────┐
│ subscriptions · nodes · latency · traffic · conns │
└───────┬───────────────────────────┬───────────────┘
        │ control (HTTP + secret)   │ Clash API — the same for both cores
┌───────┴──────── core/ (Go) ───────┴───────────────┐
│ daemon: /fetch /start /stop /status …              │
│ detect: config format → which core                 │
│ convert: links → mihomo config                     │
│ engine.Manager: one active core                    │
│   ├─ sing-box 1.14.x (as a library)                │
│   └─ mihomo 1.19.x  (as a library)                 │
└────────────────────────────────────────────────────┘
 Windows: solahelm-core.exe next to the client, talks over 127.0.0.1
 Android: gomobile .aar inside the app + VpnService (TUN fd)
```

Both cores are built **into one Go binary**: mihomo keeps its forks of quic-go/gvisor/sing under other
module paths, so nothing conflicts. The only change: mihomo's protobuf `replace` from its `go.mod` is not
carried over — that fork doesn't compile together with sing-box, the regular protobuf works.

The UI doesn't need to know which core runs: sing-box gets `experimental.clash_api`, mihomo gets
`external-controller`, and from there all requests (`/proxies`, latency, traffic, `/connections`, `/logs`)
are the same.

### Picking the core

| Input | Core |
|---|---|
| JSON with `outbounds` / `inbounds` / `route` … | sing-box |
| YAML/JSON with `proxies` / `proxy-groups` / `rules` / `mixed-port` … | mihomo |
| Links (`hysteria2://`, `vless://` …), plain or base64 | mihomo: the links become a mihomo config |

A list of links becomes a complete mihomo config (`core/convert`; the link parser is mihomo's own):
groups `Proxy` (manual) and `Auto` (by latency), DNS through the tunnel, TUN, local networks direct.
Links mihomo can't run (Naive, MASQUE) are skipped — the subscription card says so.
A list of links has no rules of its own, so the client adds a routing template (Settings → Routing):
**Russia direct** (the default, like the panel's template: Russian sites and apps, torrents and the local
network bypass the VPN, blocked sites and everything else go through it; the legiz-ru and MetaCubeX rule
sets are downloaded through the VPN itself and cached) or **Everything via VPN**.

### Windows

The client starts `solahelm-core.exe serve` and talks to it over loopback HTTP with a secret. The core
watches the client process and stops if it's gone, so TUN and the system proxy never stay behind. The
system proxy saves the previous WinINet settings and restores them on stop. TUN needs administrator
rights: the client itself runs without them, and the core is restarted elevated when needed (one UAC
prompt, none when UAC is off); if that's refused, the client shows an error.

"Exit, keep the VPN on" (tray menu): the core stops watching the window, its address and secret are kept
in `core/session.json`, and the next start of the client picks the core up. Updates: the client checks the
latest release of this repository, downloads the zip (through the core's local port when the VPN is on),
and `install.ps1` unpacks it in place (the `userdata` folder and `portable.txt` are kept).

### Android

- The cores are built into `solahelm-core.aar` (gomobile, package `core/mobile`) and run inside the app —
  the same control service as `solahelm-core.exe`. Built with the `cmfa` tag, like Clash Meta for Android:
  mihomo doesn't try to read the system package list.
- `VpnService` opens the TUN (`172.19.0.1/30`, `fdfe:dcba:9876::1/126`, DNS `172.19.0.2`) and the core gets
  the ready descriptor. The app itself is excluded from the VPN, so the cores' own connections don't loop.
- sing-box gets its own platform interface (`core/engine/singbox_android.go`): TUN from the descriptor,
  socket protection, the current network from `ConnectivityManager` instead of netlink, `local` DNS through
  the real network's DNS servers, connection owners through `getConnectionOwnerUid`.
- The quick-settings tile (`VpnTileService`) turns the VPN on without the UI: the core remembers the last
  successful start (`last-start.json`) and repeats it; an open app notices and updates.
- Android won't keep a VPN running in the background without a notification; in the settings it can be
  folded (a minimum-importance channel) or turned off entirely in Android's settings.

### Rules and settings

Rules are kept apart from the subscription, in Clash syntax: `TYPE,PAYLOAD,TARGET[,no-resolve]`. For mihomo
profiles the list replaces the profile's rules; for sing-box the rules are translated (DOMAIN*, IP-CIDR,
ports, PROCESS-*, RULE-SET, NETWORK, MATCH → final) and go in front of the profile's rules, right after the
sniff/hijack-dns service rules. The core checks the rules before they're saved.

"Connection and TUN" and "Core" settings (`engine.Tuning`) apply to both cores on top of the profile; when
changed while connected, a Reconnect button appears. DNS mode (mihomo profiles and link subscriptions;
sing-box profiles keep their own DNS), also on the main settings page in the simple interface:
- **From the profile** — leave it as it is.
- **Own, via the VPN** — `respect-rules`, remote resolvers through the VPN, direct ones for VPN servers and
  direct traffic.
- **Own, direct** — every query goes to your servers around the VPN.
- **System** — every query goes to the OS / network resolvers (mihomo `system`) around the VPN.

The last two show your ISP which sites you open.

## Building

You need Go 1.26+ and Flutter 3.x; for Windows — Visual Studio Build Tools (C++) and Windows Developer Mode
(symlinks for Flutter plugins); for Android — Android SDK, NDK r28, JDK 17 and `gomobile`
(`go install golang.org/x/mobile/cmd/gomobile@latest && gomobile init`).

```powershell
# Windows: setup.exe and two archives in dist\ (regular and portable); setup.exe needs Inno Setup 6
powershell -ExecutionPolicy Bypass -File tools\package-windows.ps1
```

```bash
# Android: two APKs in dist/
bash tools/package-android.sh
```

Android release builds are signed with the key from `app/android/key.properties` (not in git); without it,
with the debug key. GitHub release: `tools\release.ps1` (checks that `pubspec.yaml` and `appVersion` match,
publishes the archives and APKs with `gh`).

Checks:

```powershell
cd core
.\build.ps1 -Test          # Go tests + bin\corectl.exe
.\bin\corectl.exe detect https://panel.example.org/<prefix>/sub/<token>/clash
.\bin\corectl.exe test   https://panel.example.org/<prefix>/sub/<token>/singbox
cd ..\app
flutter analyze; flutter test
```

`corectl test` runs a config in port-only mode (everything on 127.0.0.1), measures every proxy's latency
through the Clash API, shows the group choices and the external IP, then stops. Without `solahelm-core`
next to it (or with `--dart-define=DEMO=true`) the app runs on demo data.

## Layout

- `core/engine` — core wrappers, `Manager` (one core at a time), rules, settings, the Android platform.
- `core/detect` — format detection and core choice; `core/convert` — links → mihomo config.
- `core/daemon` — the control HTTP service; `core/mobile` — the Android API (gomobile).
- `core/cmd/corectl` — the command-line tool and `solahelm-core.exe`: `detect`, `run`, `test`, `serve`, `version`.
- `app/` — the Flutter app: `lib/screens` — screens, `lib/state` — state and settings, `lib/core` — talking to
  the core, `lib/l10n` — RU/EN strings; `android/` — VpnService, the tile, the bridge to the core.
- `tools/` — building, packaging, releasing.

## What's tested

- SolaHelm subscriptions (sing-box JSON, Clash YAML with the built-in template and both routing presets,
  universal links) are detected and start in their core; every proxy shows up through the Clash API.
- Windows 11: port-only, system proxy (restoring the previous settings) and TUN for both cores; the core
  stops when the client disappears; exit with the VPN kept on; auto-update.
- Android 16 (arm64): a universal subscription (mihomo) and a sing-box JSON subscription in TUN mode —
  traffic goes through the VPN; connect, disconnect, reconnect; the tile with the app closed; switching
  Wi-Fi ↔ mobile data.
- Integration test `app/test/daemon_integration_test.dart` (needs `SOLAHELM_CORE` and `SOLAHELM_SUB`) —
  subscription, start, nodes, latency, node selection, traffic, stop for both cores.

## Known issues

- mihomo with the panel template's DNS settings (Cloudflare DoH + `prefer-h3`) sometimes answers slowly in
  TUN on Windows. The DNS mode "Own, via the VPN" helps.
- mihomo keeps `cache.db` open until the process ends, so its working folder is permanent.
- If a port from the config is taken by another client, mihomo carries on without that port.
- The panel's sing-box JSON subscription has no Naive, the links do (mihomo skips them).

## Roadmap

1. Android: split tunneling (choose apps), app names instead of package names, auto-update.
2. Linux: build, AppImage/deb.

## License

GPL-3.0 — see [LICENSE](LICENSE). The client is built together with [sing-box](https://github.com/SagerNet/sing-box)
and [mihomo](https://github.com/MetaCubeX/mihomo), which are GPL-3.0, so the whole project is too.

## Made with Claude

Everything in this project — the code, the build, the documentation — was created with the help of **Claude**,
the AI assistant by **Anthropic**, working as a coding agent (Claude Code). Many thanks to Anthropic for building
it and making this kind of work possible. Review the code before relying on it.
