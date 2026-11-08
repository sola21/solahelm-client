import 'dart:io';

import 'android_backend.dart';

/// Opens [url] in the default browser.
Future<void> openUrl(String url) async {
  if (Platform.isAndroid) {
    await AndroidBridge.channel.invokeMethod<void>('openUrl', {'url': url});
  } else if (Platform.isWindows) {
    await Process.start('rundll32', ['url.dll,FileProtocolHandler', url]);
  } else if (Platform.isMacOS) {
    await Process.start('open', [url]);
  } else {
    await Process.start('xdg-open', [url]);
  }
}
