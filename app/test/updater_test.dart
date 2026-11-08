import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:solahelm_client/core/updater.dart';

void main() {
  test('version comparison', () {
    expect(compareVersions('0.2.0', '0.1.0'), greaterThan(0));
    expect(compareVersions('v0.1.0', '0.1.0'), 0);
    expect(compareVersions('0.1.10', '0.1.9'), greaterThan(0));
    expect(compareVersions('1.0.0', '1.0.0-alpha.1'), greaterThan(0));
    expect(compareVersions('1.0.0-alpha.2', '1.0.0-alpha.1'), greaterThan(0));
    expect(compareVersions('0.1', '0.1.0'), 0);
    expect(compareVersions('0.1.0', '0.2.0'), lessThan(0));
  });

  test('installer replaces app files but keeps userdata and portable.txt', () async {
    if (!Platform.isWindows) return;
    final root = await Directory.systemTemp.createTemp('solahelm-install-');
    addTearDown(() => root.delete(recursive: true));
    final sep = Platform.pathSeparator;
    String p(String rel) => '${root.path}$sep$rel';

    // Installed app (old), with user data.
    final app = Directory(p('app'))..createSync();
    File(p('app${sep}solahelm_client.exe')).writeAsStringSync('old exe');
    File(p('app${sep}solahelm-core.exe')).writeAsStringSync('old core');
    Directory(p('app${sep}data')).createSync();
    File(p('app${sep}data${sep}app.so')).writeAsStringSync('old so');
    File(p('app${sep}portable.txt')).writeAsStringSync('mine');
    Directory(p('app${sep}userdata')).createSync();
    File(p('app${sep}userdata${sep}ui.json')).writeAsStringSync('{"theme":"dark"}');

    // New release archive.
    final src = Directory(p('src'))..createSync();
    File('${src.path}${sep}solahelm_client.exe').writeAsStringSync('new exe');
    File('${src.path}${sep}solahelm-core.exe').writeAsStringSync('new core');
    Directory('${src.path}${sep}data').createSync();
    File('${src.path}${sep}data${sep}app.so').writeAsStringSync('new so');
    File('${src.path}${sep}portable.txt').writeAsStringSync('from release');
    final updDir = Directory(p('upd'))..createSync();
    final zip = '${updDir.path}${sep}update.zip';
    final z = await Process.run('powershell', [
      '-NoProfile', '-Command', "Compress-Archive -Path '${src.path}$sep*' -DestinationPath '$zip'",
    ]);
    expect(z.exitCode, 0, reason: '${z.stderr}');

    final script = File('${updDir.path}${sep}install.ps1')..writeAsStringSync(Updater.installScript);
    final r = await Process.run('powershell', [
      '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', script.path,
      '-Zip', zip, '-AppDir', app.path, '-Exe', p('app${sep}solahelm_client.exe'), '-NoStart',
    ]);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');

    expect(File(p('app${sep}solahelm_client.exe')).readAsStringSync(), 'new exe');
    expect(File(p('app${sep}solahelm-core.exe')).readAsStringSync(), 'new core');
    expect(File(p('app${sep}data${sep}app.so')).readAsStringSync(), 'new so');
    expect(File(p('app${sep}portable.txt')).readAsStringSync(), 'mine');
    expect(File(p('app${sep}userdata${sep}ui.json')).readAsStringSync(), '{"theme":"dark"}');
    expect(File('${updDir.path}${sep}install.log').readAsStringSync(), contains('updated'));
  });

  test('check against the real repository', () async {
    if (Platform.environment['SOLAHELM_NET_TESTS'] == null) return;
    final u = Updater(currentVersion: '0.0.1', portable: false);
    final info = await u.check();
    // ignore: avoid_print
    print('has release: ${u.lastHadRelease}, update: ${info?.version}');
    if (!u.lastHadRelease) expect(info, isNull);
  });
}
