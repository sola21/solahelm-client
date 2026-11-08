#!/usr/bin/env bash
# Builds the Android APKs (core AAR + Flutter app) into dist/:
#   SolaHelm-<version>-android-arm64.apk   phones (almost all of them)
#   SolaHelm-<version>-android-x86_64.apk  emulators, some Chromebooks
# Needs what core/build-android.sh needs, plus Flutter. Signed with the release key from
# app/android/key.properties (not in git); without it, with the debug key.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
version=$(sed -n 's/^version:[[:space:]]*\([0-9A-Za-z.\-]*\).*/\1/p' "$root/app/pubspec.yaml")
bash "$root/core/build-android.sh"
cd "$root/app"
flutter build apk --release --split-per-abi --target-platform android-arm64,android-x64
mkdir -p "$root/dist"
out="$root/app/build/app/outputs/flutter-apk"
cp "$out/app-arm64-v8a-release.apk" "$root/dist/SolaHelm-$version-android-arm64.apk"
cp "$out/app-x86_64-release.apk" "$root/dist/SolaHelm-$version-android-x86_64.apk"
ls -l "$root/dist/"SolaHelm-"$version"-android-*.apk
