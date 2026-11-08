// End-to-end check of the Dart side against the real core, in port-only mode
// (no TUN, no system proxy). Skipped unless both variables are set:
//   SOLAHELM_CORE=..\core\bin\solahelm-core.exe
//   SOLAHELM_SUB=https://panel/sub/<token>   (the /singbox and /clash variants are used)
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:solahelm_client/core/daemon_backend.dart';
import 'package:solahelm_client/models.dart';

void main() {
  final exe = Platform.environment['SOLAHELM_CORE'];
  final sub = Platform.environment['SOLAHELM_SUB'];
  final skip = (exe == null || sub == null) ? 'set SOLAHELM_CORE and SOLAHELM_SUB' : null;

  for (final variant in ['/singbox', '/clash']) {
    test('daemon round trip $variant', () async {
      final work = await Directory.systemTemp.createTemp('solahelm-it-');
      final b = DaemonBackend(executable: exe!, workDir: work.path);
      addTearDown(() async {
        await b.dispose();
        try {
          await work.delete(recursive: true);
        } catch (_) {}
      });

      final f = await b.fetch('$sub$variant');
      expect(f.format, variant == '/clash' ? SubFormat.clashYaml : SubFormat.singBoxJson);
      expect(f.content, isNotEmpty);
      // ignore: avoid_print
      print('$variant: core=${f.core} title=${f.title} total=${f.total} expire=${f.expire}');

      final st = await b.start(content: f.content, core: CorePref.auto, mode: ProxyMode.portOnly, port: 7890);
      expect(st.running, isTrue);
      expect(st.core, variant == '/clash' ? CoreKind.mihomo : CoreKind.singBox);
      // ignore: avoid_print
      print('$variant: running on port ${st.port}, elevated=${st.elevated}');

      final snap = await b.proxies();
      expect(snap.leaves, isNotEmpty);
      final selector = snap.groups.firstWhere((g) => g.selectable);
      // ignore: avoid_print
      print('$variant: ${snap.leaves.length} proxies, groups ${snap.groups.map((g) => '${g.name}(${g.type})').join(', ')}');

      final first = snap.leaves.keys.first;
      final d = await b.delay(first);
      // ignore: avoid_print
      print('$variant: delay $first = $d');
      expect(d, isNotNull);

      final target = selector.members.firstWhere((m) => snap.leaves.containsKey(m));
      await b.select(selector.name, target);
      final after = await b.proxies();
      expect(after.groups.firstWhere((g) => g.name == selector.name).now, target);

      // Traffic through the local port shows up in the core's counters.
      final client = HttpClient()..findProxy = (_) => 'PROXY 127.0.0.1:${st.port}';
      final req = await client.getUrl(Uri.parse('https://www.gstatic.com/generate_204'));
      final resp = await req.close();
      await resp.drain<void>();
      client.close();
      expect(resp.statusCode, 204);
      final t = await b.traffic();
      expect(t.downloadTotal, greaterThan(0));

      final stopped = await b.stop();
      expect(stopped.running, isFalse);
    }, skip: skip, timeout: const Timeout(Duration(minutes: 2)));
  }
}
