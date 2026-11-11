import 'package:flutter_test/flutter_test.dart';
import 'package:solahelm_client/state/settings.dart';

void main() {
  test('DNS mode: default keeps the profile DNS', () {
    final cs = CoreSettings.fromJson(<String, dynamic>{});
    expect(cs.dnsMode, CoreSettings.dnsProfile);
    expect(cs.tuning().containsKey('dns'), isFalse);
  });

  test('DNS mode: the 0.3.1 switch becomes "own servers through the VPN"', () {
    expect(CoreSettings.fromJson({'dnsOverride': true}).dnsMode, CoreSettings.dnsVpn);
    expect(CoreSettings.fromJson({'dnsOverride': false}).dnsMode, CoreSettings.dnsProfile);
    expect(CoreSettings.fromJson({'dnsMode': 'bogus'}).dnsMode, CoreSettings.dnsProfile);
  });

  test('DNS mode: what the core gets', () {
    final base = CoreSettings.fromJson(<String, dynamic>{});
    for (final m in CoreSettings.dnsModes) {
      final cs = CoreSettings.fromJson(base.copyWith(dnsMode: m).toJson());
      expect(cs.dnsMode, m, reason: 'round trip');
      final dns = cs.tuning()['dns'] as Map?;
      if (m == CoreSettings.dnsProfile) {
        expect(dns, isNull);
        continue;
      }
      expect(dns!['mode'], m);
      if (m == CoreSettings.dnsVpn) expect(dns['remote'], isNotEmpty);
      if (m != CoreSettings.dnsSystem) expect(dns['direct'], isNotEmpty);
    }
    // Own servers with an empty list: nothing to use, the profile's DNS stays.
    final empty = base.copyWith(dnsMode: CoreSettings.dnsDirectMode, dnsDirect: const []);
    expect(empty.tuning().containsKey('dns'), isFalse);
  });
}
