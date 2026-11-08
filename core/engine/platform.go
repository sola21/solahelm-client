package engine

import (
	"sync"
)

// Hooks the Android app (package mobile) fills in. On desktop they stay unset.

// SocketProtector keeps a socket out of the VPN (VpnService.protect).
var SocketProtector func(fd int) error

// DefaultInterface is the device's real (non-VPN) network as Android reports it.
type DefaultInterface struct {
	Name  string
	Index int // -1: no network
}

var (
	defaultIfMu        sync.Mutex
	defaultIf          = DefaultInterface{Index: -1}
	defaultIfListeners = map[int]func(DefaultInterface){}
	defaultIfNextID    int
)

// SetDefaultInterface records a change of the real network (Wi-Fi <-> mobile)
// and tells a running sing-box about it.
func SetDefaultInterface(name string, index int) {
	defaultIfMu.Lock()
	defaultIf = DefaultInterface{Name: name, Index: index}
	cur := defaultIf
	listeners := make([]func(DefaultInterface), 0, len(defaultIfListeners))
	for _, l := range defaultIfListeners {
		listeners = append(listeners, l)
	}
	defaultIfMu.Unlock()
	for _, l := range listeners {
		l(cur)
	}
}

func currentDefaultInterface() DefaultInterface {
	defaultIfMu.Lock()
	defer defaultIfMu.Unlock()
	return defaultIf
}

func watchDefaultInterface(f func(DefaultInterface)) (cancel func()) {
	defaultIfMu.Lock()
	id := defaultIfNextID
	defaultIfNextID++
	defaultIfListeners[id] = f
	defaultIfMu.Unlock()
	return func() {
		defaultIfMu.Lock()
		delete(defaultIfListeners, id)
		defaultIfMu.Unlock()
	}
}

var (
	systemDNSMu sync.Mutex
	systemDNS   []string
)

// SetSystemDNSServers records the DNS servers of the real network (IPs). On
// Android sing-box's "local" DNS server uses them: there is no
// /etc/resolv.conf to read.
func SetSystemDNSServers(servers []string) {
	systemDNSMu.Lock()
	systemDNS = append([]string(nil), servers...)
	systemDNSMu.Unlock()
}

func systemDNSServers() []string {
	systemDNSMu.Lock()
	defer systemDNSMu.Unlock()
	return append([]string(nil), systemDNS...)
}

// ConnectionOwnerFinder looks up the app behind a connection from the TUN
// (Android: ConnectivityManager.getConnectionOwnerUid). proto is the IP
// protocol number (6 TCP, 17 UDP). ok=false: unknown.
var ConnectionOwnerFinder func(proto int32, srcIP string, srcPort int32, dstIP string, dstPort int32) (uid int32, packages []string, ok bool)
