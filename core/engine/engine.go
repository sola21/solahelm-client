// Package engine wraps the sing-box and mihomo cores behind one interface.
//
// Both cores live in the same binary; only one runs at a time. Whatever core is
// running, the client talks to it through a Clash-compatible REST API
// (mihomo external-controller / sing-box experimental.clash_api), so the UI does
// not need to know which core is active.
package engine

import (
	"errors"
	"fmt"
	"sync"
)

// AndroidTunAddress is the TUN address the Android VpnService sets up; the
// core must use the same one.
const (
	AndroidTunAddress  = "172.19.0.1/30"
	AndroidTunAddress6 = "fdfe:dcba:9876::1/126"
	// AndroidTunMTU is the interface MTU when Tuning.MTU is not set (the app uses the same default).
	AndroidTunMTU uint32 = 1500
)

// Kind names a proxy core.
type Kind string

const (
	SingBox Kind = "sing-box"
	Mihomo  Kind = "mihomo"
)

func (k Kind) Valid() bool { return k == SingBox || k == Mihomo }

// Options are applied on top of the user's config when a core starts.
type Options struct {
	// WorkDir holds core state: caches, geo databases, rule sets.
	WorkDir string
	// Controller is the listen address of the Clash-compatible API, e.g. "127.0.0.1:9090".
	// Empty keeps whatever the config says.
	Controller string
	// Secret protects the API. Used only together with Controller.
	Secret string
	// ProxyOnly drops TUN (and redirect/tproxy) inbounds and turns off
	// system-proxy switching, so the OS routing stays untouched. Implies
	// LoopbackOnly. This is the "port only" mode of the client.
	ProxyOnly bool
	// LoopbackOnly binds every local listener (mixed/socks/http ports) to
	// 127.0.0.1 and turns off allow-lan, so nothing is reachable from the LAN.
	LoopbackOnly bool
	// TUNStack overrides the TUN stack: "gvisor", "system" or "mixed".
	// gvisor keeps the whole TCP/IP stack in user space and opens no sockets,
	// so Windows Firewall does not prompt for it.
	TUNStack string
	// FindProcess makes the core find the process behind every connection, so
	// the connections screen can group by application.
	FindProcess bool
	// Rules are user rules in Clash syntax (see type Rules).
	Rules *Rules
	// Tuning overrides profile settings from the app's settings.
	Tuning *Tuning
	// TunFD is a TUN device opened by the OS (Android VpnService). The OS
	// owns routes and addresses; the core only reads and writes packets.
	TunFD int
	// MixedPort, when non-zero, is the local HTTP+SOCKS port. It replaces the
	// config's own mixed port (or adds one) so the client can avoid busy ports.
	MixedPort int
}

// Engine is one proxy core.
type Engine interface {
	Kind() Kind
	Start(config []byte, opts Options) error
	Stop() error
}

// New returns an engine of the given kind.
func New(k Kind) (Engine, error) {
	switch k {
	case SingBox:
		return &singBox{}, nil
	case Mihomo:
		return &mihomoEngine{}, nil
	}
	return nil, fmt.Errorf("unknown core %q", k)
}

// ErrNotRunning is returned by Manager.Stop when nothing runs.
var ErrNotRunning = errors.New("no core is running")

// Manager keeps at most one running core and switches between them.
type Manager struct {
	mu      sync.Mutex
	current Engine
}

// Start stops the running core (if any) and starts a core of kind k.
func (m *Manager) Start(k Kind, config []byte, opts Options) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.current != nil {
		_ = m.current.Stop()
		m.current = nil
	}
	e, err := New(k)
	if err != nil {
		return err
	}
	if err := e.Start(config, opts); err != nil {
		_ = e.Stop()
		return fmt.Errorf("%s: %w", k, err)
	}
	m.current = e
	return nil
}

// Stop stops the running core.
func (m *Manager) Stop() error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.current == nil {
		return ErrNotRunning
	}
	err := m.current.Stop()
	m.current = nil
	return err
}

// Running reports the kind of the running core, or "" when idle.
func (m *Manager) Running() Kind {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.current == nil {
		return ""
	}
	return m.current.Kind()
}
