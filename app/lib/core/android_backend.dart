import 'package:flutter/services.dart';

import 'daemon_backend.dart';

/// Builds the Android backend: the Go daemon runs inside the app (gomobile)
/// and the TUN comes from SolaHelmVpnService through "solahelm/android".
class AndroidBridge {
  static const channel = MethodChannel('solahelm/android');

  /// Called when Android revokes the VPN (another VPN app, or turned off in settings).
  static void Function()? onRevoked;

  /// Called when the quick-settings tile or the notification turned the VPN on or off.
  static void Function()? onCoreChanged;

  /// How visible the "VPN is running" notification is (false: folded).
  static Future<void> setNotificationVisible(bool visible) =>
      channel.invokeMethod<void>('setNotificationVisible', {'visible': visible});

  /// Android's settings for the folded notification, where it can be turned off.
  static Future<void> openNotificationSettings() => channel.invokeMethod<void>('openNotificationSettings');

  static DaemonBackend backend(String workDir) {
    channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'vpnRevoked':
          onRevoked?.call();
        case 'coreChanged':
          onCoreChanged?.call();
      }
    });
    return DaemonBackend.inProcess(
      workDir: workDir,
      start: () async {
        final m = await channel.invokeMapMethod<String, dynamic>('coreStart', {'workDir': workDir});
        return (m!['addr'] as String, m['secret'] as String);
      },
      openTun: (mtu) async {
        final fd = await channel.invokeMethod<int>('vpnStart', {'mtu': mtu, 'excludeLan': true, 'title': 'SolaHelm'});
        return fd!;
      },
      closeTun: () => channel.invokeMethod<void>('vpnStop'),
    );
  }
}
