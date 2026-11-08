import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A newer release on GitHub.
class UpdateInfo {
  const UpdateInfo({required this.version, required this.notes, required this.url, required this.size, required this.page});
  final String version; // "0.2.0"
  final String notes;
  final String url; // zip asset
  final int size;
  final String page; // release page
}

/// Compares "1.2.3", "v1.2.3", "1.2.3-alpha.2": a > b → positive.
int compareVersions(String a, String b) {
  List<Object> parse(String v) {
    v = v.trim().replaceFirst(RegExp(r'^v'), '');
    final dash = v.indexOf('-');
    final core = (dash < 0 ? v : v.substring(0, dash)).split('.').map((e) => int.tryParse(e) ?? 0).toList();
    while (core.length < 3) {
      core.add(0);
    }
    return [...core.take(3), dash < 0 ? '' : v.substring(dash + 1)];
  }

  final x = parse(a), y = parse(b);
  for (var i = 0; i < 3; i++) {
    final d = (x[i] as int).compareTo(y[i] as int);
    if (d != 0) return d;
  }
  final px = x[3] as String, py = y[3] as String;
  if (px == py) return 0;
  if (px.isEmpty) return 1; // 1.0.0 > 1.0.0-alpha
  if (py.isEmpty) return -1;
  return px.compareTo(py);
}

/// Checks GitHub Releases and installs updates of the Windows build.
class Updater {
  Updater({required this.currentVersion, required this.portable, this.repo = 'sola21/solahelm-client', bool? installed})
      : installed = installed ?? (!portable && _hasUninstaller(File(Platform.resolvedExecutable).parent.path));

  final String currentVersion;
  final bool portable;
  final String repo;

  /// Installed by SolaHelm-*-setup.exe (Inno Setup leaves unins000.exe):
  /// updated by the next setup, so Windows' list of programs stays right.
  final bool installed;

  static bool _hasUninstaller(String dir) => File('$dir${Platform.pathSeparator}unins000.exe').existsSync();

  /// After check(): whether the repository has any release at all.
  bool lastHadRelease = false;

  /// The newest release if it's newer than ours, else null.
  /// [proxyPort]: the core's local port, used when set (github.com may be blocked).
  Future<UpdateInfo?> check({int? proxyPort}) async {
    final uri = Uri.parse('https://api.github.com/repos/$repo/releases/latest');
    Map<String, dynamic>? m;
    try {
      m = await _getJson(uri, proxyPort);
    } catch (_) {
      // api.github.com answers 5xx or times out now and then on some networks.
      await Future<void>.delayed(const Duration(seconds: 2));
      m = await _getJson(uri, proxyPort);
    }
    lastHadRelease = m != null;
    if (m == null) return null; // no releases yet
    final tag = (m['tag_name'] ?? '').toString();
    if (tag.isEmpty || compareVersions(tag, currentVersion) <= 0) return null;
    // An installed copy prefers the setup, and falls back to the zip.
    final wants = [
      if (portable) '-windows-x64-portable.zip',
      if (!portable && installed) '-windows-x64-setup.exe',
      if (!portable) '-windows-x64.zip',
    ];
    final assets = ((m['assets'] as List?) ?? const []).cast<Map>();
    for (final want in wants) {
      final a = assets.where((a) => (a['name'] ?? '').toString().endsWith(want)).firstOrNull;
      if (a != null) {
        return UpdateInfo(
          version: tag.replaceFirst(RegExp(r'^v'), ''),
          notes: (m['body'] ?? '').toString(),
          url: (a['browser_download_url'] ?? '').toString(),
          size: (a['size'] as num?)?.toInt() ?? 0,
          page: (m['html_url'] ?? '').toString(),
        );
      }
    }
    return null;
  }

  HttpClient _client(int? proxyPort) {
    final c = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..userAgent = 'solahelm-client/$currentVersion';
    if (proxyPort != null) c.findProxy = (_) => 'PROXY 127.0.0.1:$proxyPort; DIRECT';
    return c;
  }

  Future<Map<String, dynamic>?> _getJson(Uri uri, int? proxyPort) async {
    final c = _client(proxyPort);
    try {
      final req = await c.getUrl(uri);
      req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final resp = await req.close().timeout(const Duration(seconds: 20));
      final text = await resp.transform(utf8.decoder).join();
      if (resp.statusCode == 404) return null;
      if (resp.statusCode != 200) throw HttpException('GitHub answered ${resp.statusCode}');
      return jsonDecode(text) as Map<String, dynamic>;
    } finally {
      c.close(force: true);
    }
  }

  /// Downloads the update zip; [onProgress] gets 0..1.
  Future<File> download(UpdateInfo info, {int? proxyPort, void Function(double)? onProgress}) async {
    final dir = await Directory.systemTemp.createTemp('solahelm-update-');
    final name = info.url.toLowerCase().endsWith('.exe') ? 'update-setup.exe' : 'update.zip';
    final file = File('${dir.path}${Platform.pathSeparator}$name');
    final c = _client(proxyPort);
    try {
      final req = await c.getUrl(Uri.parse(info.url));
      final resp = await req.close().timeout(const Duration(seconds: 30));
      if (resp.statusCode != 200) throw HttpException('Download failed: HTTP ${resp.statusCode}');
      final total = resp.contentLength > 0 ? resp.contentLength : info.size;
      final sink = file.openWrite();
      var got = 0;
      await for (final chunk in resp) {
        sink.add(chunk);
        got += chunk.length;
        if (total > 0) onProgress?.call(got / total);
      }
      await sink.close();
      if (info.size > 0 && await file.length() != info.size) throw const HttpException('The download is incomplete');
      return file;
    } finally {
      c.close(force: true);
    }
  }

  /// Writes the installer script and starts it. The caller exits right
  /// after; the script waits for this process, then unpacks the zip over the
  /// app folder (userdata and portable.txt stay) or runs the setup silently,
  /// and starts the app again. [appDir], [exe] and [start] are for tests.
  Future<void> install(File update, {required bool reconnect, String? appDir, String? exe, bool start = true}) async {
    appDir ??= File(Platform.resolvedExecutable).parent.path;
    exe ??= Platform.resolvedExecutable;
    final setup = update.path.toLowerCase().endsWith('.exe');
    final script = File('${update.parent.path}${Platform.pathSeparator}install.ps1');
    await script.writeAsString(installScript, flush: true);
    final args = [
      '-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', script.path,
      '-WaitPid', '$pid', if (setup) ...['-Setup', update.path] else ...['-Zip', update.path],
      '-AppDir', appDir, '-Exe', exe,
      if (reconnect) '-Reconnect',
      if (!start) '-NoStart',
    ];
    // Not ProcessStartMode.detached: that starts powershell.exe without any
    // console (DETACHED_PROCESS) and it quits at once, so nothing got installed.
    // A normal child keeps running after this app exits.
    if (_writable(appDir)) {
      await Process.start('powershell.exe', args);
    } else {
      // e.g. installed under Program Files: run the installer elevated.
      String q(String s) => "'${s.replaceAll("'", "''")}'";
      final argLine = args.map((a) => a.startsWith('-') ? a : '"$a"').join(' ');
      await Process.start('powershell.exe', [
        '-NoProfile', '-WindowStyle', 'Hidden', '-Command',
        'Start-Process -FilePath powershell.exe -ArgumentList ${q(argLine)} -Verb RunAs -WindowStyle Hidden',
      ]);
    }
  }

  bool _writable(String dir) {
    try {
      final f = File('$dir${Platform.pathSeparator}.write-test');
      f.writeAsStringSync('x');
      f.deleteSync();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// The installer, kept here so the app can always write it out.
  static const installScript = r'''
param([int]$WaitPid, [string]$Zip, [string]$Setup, [string]$AppDir, [string]$Exe, [switch]$Reconnect, [switch]$NoStart)
$ErrorActionPreference = 'Stop'
$log = Join-Path (Split-Path -Parent $(if ($Setup) { $Setup } else { $Zip })) 'install.log'
function Log($m) { Add-Content -Path $log -Value ("{0:HH:mm:ss} {1}" -f (Get-Date), $m) }
Log 'started'
try {
  if ($WaitPid) {
    $p = Get-Process -Id $WaitPid -ErrorAction SilentlyContinue
    if ($p) { $p.WaitForExit(30000) | Out-Null }
  }
  # The core may still be stopping; wait until its exe is free.
  $core = Join-Path $AppDir 'solahelm-core.exe'
  for ($i = 0; $i -lt 40; $i++) {
    try { [IO.File]::Open($core, 'Open', 'ReadWrite', 'None').Close(); break } catch { Start-Sleep -Milliseconds 250 }
  }
  if ($Setup) {
    $p = Start-Process -FilePath $Setup -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-' -PassThru -Wait
    if ($p.ExitCode -ne 0) { throw ("setup exit code " + $p.ExitCode) }
  } else {
    $stage = Join-Path (Split-Path -Parent $Zip) 'new'
    if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
    Expand-Archive -Path $Zip -DestinationPath $stage
    if (-not (Test-Path (Join-Path $stage 'solahelm_client.exe'))) { throw 'the archive has no solahelm_client.exe' }
    Get-ChildItem $stage | Where-Object { $_.Name -notin @('userdata', 'portable.txt') } | ForEach-Object {
      Copy-Item -Path $_.FullName -Destination $AppDir -Recurse -Force
    }
  }
  Log 'updated'
} catch {
  Log ("failed: " + $_.Exception.Message)
}
if (-not $NoStart) {
  $a = @()
  if ($Reconnect) { $a += '--connect' }
  if ($a.Count) { Start-Process -FilePath $Exe -ArgumentList $a } else { Start-Process -FilePath $Exe }
}
''';
}
