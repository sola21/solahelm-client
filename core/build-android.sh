#!/usr/bin/env bash
# Builds app/android/app/libs/solahelm-core.aar (both cores + the daemon) with gomobile.
# Needs Go, gomobile (go install golang.org/x/mobile/cmd/gomobile@latest; gomobile init),
# ANDROID_HOME, ANDROID_NDK_HOME and JAVA_HOME (17).
set -euo pipefail
cd "$(dirname "$0")"
SB=$(go list -m -f '{{.Version}}' github.com/sagernet/sing-box); SB=${SB#v}
MH=$(go list -m -f '{{.Version}}' github.com/metacubex/mihomo); MH=${MH#v}
mkdir -p ../app/android/app/libs
gomobile bind -target=android/arm64,android/amd64 -androidapi 24 -javapkg io.github.sola21.core \
  -ldflags "-s -w -X github.com/sagernet/sing-box/constant.Version=$SB -X github.com/metacubex/mihomo/constant.Version=$MH" \
  -tags cmfa,with_quic,with_utls,with_clash_api,with_gvisor,with_wireguard \
  -o ../app/android/app/libs/solahelm-core.aar ./mobile
echo "built ../app/android/app/libs/solahelm-core.aar (sing-box $SB, mihomo $MH)"
