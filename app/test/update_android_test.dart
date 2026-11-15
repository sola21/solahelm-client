import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solahelm_client/core/fake_backend.dart';
import 'package:solahelm_client/core/updater.dart';
import 'package:solahelm_client/main.dart';
import 'package:solahelm_client/models.dart';
import 'package:solahelm_client/state/app_state.dart';
import 'package:solahelm_client/state/settings.dart';
import 'package:solahelm_client/state/sub_store.dart';

/// An Android updater that "downloads" a local file.
class FakeApkUpdater extends Updater {
  FakeApkUpdater() : super(currentVersion: '0.4.0', portable: false, android: true, abi: 'arm64');
  int downloads = 0;

  @override
  Future<File> download(UpdateInfo info, {int? proxyPort, void Function(double)? onProgress}) async {
    downloads++;
    onProgress?.call(1);
    final dir = await Directory.systemTemp.createTemp('solahelm-apk-test-');
    return File('${dir.path}${Platform.pathSeparator}update.apk')..writeAsStringSync('apk');
  }
}

void main() {
  testWidgets('Android update: the APK goes to Android\'s installer, after the "install apps" permission', (t) async {
    final st = AppState(
      Settings(languageCode: 'ru', themeMode: ThemeMode.light, proxyMode: ProxyMode.portOnly, uiMode: UiMode.advanced, welcomeDone: true),
      FakeBackend(random: Random(1)),
      MemorySubStore(),
    );
    final u = FakeApkUpdater();
    st.updater = u;
    st.update = const UpdateInfo(version: '0.4.1', notes: 'notes', url: 'https://x/SolaHelm-0.4.1-android-arm64.apk', size: 0, page: '');
    final installs = <String>[];
    var answer = 'permission';
    st.installApk = (path) async {
      installs.add(path);
      return answer;
    };
    t.view.physicalSize = const Size(420, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await st.init();
    await t.pumpWidget(SolaHelmApp(state: st));
    await t.pumpAndSettle();

    // First tap: Android asks to allow installs from this app; the app says so.
    expect(await t.runAsync(st.downloadAndInstallUpdate), isFalse);
    await t.pumpAndSettle();
    expect(installs, hasLength(1));
    expect(find.textContaining('Разрешите установку приложений для SolaHelm'), findsOneWidget);

    // Second tap: the same file, no second download.
    answer = 'started';
    await t.runAsync(st.downloadAndInstallUpdate);
    expect(u.downloads, 1);
    expect(installs, hasLength(2));
    expect(installs[1], installs[0]);
    expect(installs[0], endsWith('update.apk'));
  });
}
