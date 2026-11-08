// Package mobile is the gomobile API for Android: it runs the same control
// daemon as solahelm-core.exe, but inside the app process, on loopback.
// The Dart side talks to it exactly as on desktop.
//
//	gomobile bind -target=android/arm64,android/amd64 -androidapi 24 \
//	  -tags cmfa,with_quic,with_utls,with_clash_api,with_gvisor,with_wireguard ./mobile
package mobile

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"net"
	"net/http"
	"strconv"
	"strings"
	"sync"

	mihomoC "github.com/metacubex/mihomo/constant"
	mihomoRoute "github.com/metacubex/mihomo/hub/route"
	singboxC "github.com/sagernet/sing-box/constant"

	"github.com/sola21/solahelm-client/core/daemon"
	"github.com/sola21/solahelm-client/core/engine"
)

// Protector keeps a socket out of the VPN (VpnService.protect on Android),
// so the cores' own connections to the proxy servers don't loop back into
// the tunnel. Implemented in Kotlin.
type Protector interface {
	Protect(fd int32) bool
}

var (
	mu      sync.Mutex
	server  *http.Server
	srv     *daemon.Server
	addr    string
	secret  string
	workDir string
)

// Versions returns "sing-box X / mihomo Y".
func Versions() string {
	return "sing-box " + singboxC.Version + " / mihomo " + mihomoC.Version
}

// Start runs the control daemon (once) and returns its address. Call Secret()
// for the API secret.
func Start(dir string, protector Protector) (string, error) {
	mu.Lock()
	defer mu.Unlock()
	if server != nil {
		return addr, nil
	}
	if protector == nil {
		return "", errors.New("protector is required")
	}
	setProtector(protector)
	// The cmfa build tag (needed so mihomo doesn't read /data/system/packages.xml)
	// also turns on "embed mode", which forbids PATCH /configs. The app uses it
	// to switch the routing mode, so turn it back off.
	mihomoRoute.SetEmbedMode(false)
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	secret = hex.EncodeToString(b)
	srv = daemon.New(secret, dir, map[string]string{"sing-box": singboxC.Version, "mihomo": mihomoC.Version})
	workDir = dir
	srv.OnStarted = saveLastStart
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return "", err
	}
	addr = l.Addr().String()
	server = &http.Server{Handler: srv.Handler()}
	go func() { _ = server.Serve(l) }()
	return addr, nil
}

// OwnerFinder finds the app behind a connection. Implemented in Kotlin with
// ConnectivityManager.getConnectionOwnerUid. Returns "uid<TAB>pkg1,pkg2", or
// "" when unknown.
type OwnerFinder interface {
	FindOwner(proto int32, srcIP string, srcPort int32, dstIP string, dstPort int32) string
}

// SetOwnerFinder lets sing-box show which app a connection belongs to.
func SetOwnerFinder(f OwnerFinder) {
	if f == nil {
		engine.ConnectionOwnerFinder = nil
		return
	}
	engine.ConnectionOwnerFinder = func(proto int32, srcIP string, srcPort int32, dstIP string, dstPort int32) (int32, []string, bool) {
		uidStr, pkgs, found := strings.Cut(f.FindOwner(proto, srcIP, srcPort, dstIP, dstPort), "\t")
		if !found {
			return 0, nil, false
		}
		uid, err := strconv.Atoi(uidStr)
		if err != nil || uid < 0 {
			return 0, nil, false
		}
		var packages []string
		if pkgs != "" {
			packages = strings.Split(pkgs, ",")
		}
		return int32(uid), packages, true
	}
}

// SetDefaultNetwork reports the device's real network (the interface Android
// routes through outside the VPN); index -1 = no network. sing-box uses it
// in place of netlink, which apps can't watch.
func SetDefaultNetwork(name string, index int32) {
	engine.SetDefaultInterface(name, int(index))
}

// Secret returns the API secret of the running daemon.
func Secret() string {
	mu.Lock()
	defer mu.Unlock()
	return secret
}

// Stop stops the core and the daemon.
func Stop() {
	mu.Lock()
	defer mu.Unlock()
	if srv != nil {
		srv.Shutdown()
	}
	if server != nil {
		_ = server.Close()
	}
	server, srv, addr = nil, nil, ""
}
