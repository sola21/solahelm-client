//go:build android

package engine

import (
	"context"
	"errors"
	"net/netip"
	"sync"
	"syscall"
	"unsafe"

	"github.com/sagernet/sing-box/adapter"
	"github.com/sagernet/sing-box/common/process"
	"github.com/sagernet/sing-box/option"
	tun "github.com/sagernet/sing-tun"
	"github.com/sagernet/sing/common/control"
	"github.com/sagernet/sing/common/logger"
	"github.com/sagernet/sing/common/x/list"
	"golang.org/x/sys/unix"
)

// androidPlatform is the sing-box platform interface for a TUN that Android's
// VpnService has already opened: sing-box gets the descriptor instead of
// creating a device, and protects its sockets through VpnService.protect.
// Everything Android-specific that sing-box could ask for (Wi-Fi state,
// connection owners, notifications...) is reported as unavailable.
type androidPlatform struct {
	mu      sync.Mutex
	tunFD   int // until OpenInterface takes it
	nm      adapter.NetworkManager
	myAddrs []netip.Addr
	monitor *androidMonitor
}

var _ adapter.PlatformInterface = (*androidPlatform)(nil)

func newSingBoxPlatform(tunFD int) singBoxPlatform {
	p := &androidPlatform{tunFD: tunFD}
	p.monitor = &androidMonitor{p: p}
	return p
}

// closeUnused closes the descriptor if sing-box failed before taking it, so
// the VPN interface doesn't stay up with nobody reading it.
func (p *androidPlatform) closeUnused() {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.tunFD > 0 {
		_ = unix.Close(p.tunFD)
		p.tunFD = 0
	}
}

func (p *androidPlatform) Initialize(nm adapter.NetworkManager) error {
	p.mu.Lock()
	p.nm = nm
	p.mu.Unlock()
	return nil
}

func (p *androidPlatform) networkManager() adapter.NetworkManager {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.nm
}

func (p *androidPlatform) UsePlatformAutoDetectInterfaceControl() bool { return true }

func (p *androidPlatform) AutoDetectInterfaceControl(fd int) error {
	if SocketProtector == nil {
		return nil // the app is excluded from its own VPN anyway
	}
	return SocketProtector(fd)
}

func (p *androidPlatform) UsePlatformInterface() bool { return true }

func (p *androidPlatform) OpenInterface(options *tun.Options, _ option.TunPlatformOptions) (tun.Tun, error) {
	p.mu.Lock()
	fd := p.tunFD
	p.tunFD = 0
	p.mu.Unlock()
	if fd <= 0 {
		return nil, errors.New("android: the VPN interface is already in use")
	}
	name, err := tunName(fd)
	if err != nil || name == "" {
		name = "tun0"
	}
	options.Name = name
	options.FileDescriptor = fd
	if options.InterfaceMonitor != nil {
		options.InterfaceMonitor.RegisterMyInterface(name)
	}
	addrs := make([]netip.Addr, 0, len(options.Inet4Address)+len(options.Inet6Address))
	for _, pfx := range options.Inet4Address {
		addrs = append(addrs, pfx.Addr())
	}
	for _, pfx := range options.Inet6Address {
		addrs = append(addrs, pfx.Addr())
	}
	p.mu.Lock()
	p.myAddrs = addrs
	p.mu.Unlock()
	t, err := tun.New(*options)
	if err != nil {
		_ = unix.Close(fd)
	}
	return t, err
}

func (p *androidPlatform) ProcessPlatformOptions(option.TunPlatformOptions) error { return nil }

func (p *androidPlatform) UsePlatformDefaultInterfaceMonitor() bool { return true }

func (p *androidPlatform) CreateDefaultInterfaceMonitor(l logger.Logger) tun.DefaultInterfaceMonitor {
	p.monitor.logger = l
	return p.monitor
}

func (p *androidPlatform) UsePlatformNetworkInterfaces() bool { return false }
func (p *androidPlatform) NetworkInterfaces() ([]adapter.NetworkInterface, error) {
	return nil, errors.ErrUnsupported
}
func (p *androidPlatform) UnderNetworkExtension() bool              { return false }
func (p *androidPlatform) NetworkExtensionIncludeAllNetworks() bool { return false }
func (p *androidPlatform) ClearDNSCache()                           {}
func (p *androidPlatform) RequestPermissionForWIFIState() error     { return nil }
func (p *androidPlatform) ReadWIFIState(context.Context) adapter.WIFIState {
	return adapter.WIFIState{}
}

// On Android sing-box always looks up connection owners; without the
// platform finder it would try netlink, which apps aren't allowed to use.
func (p *androidPlatform) UsePlatformConnectionOwnerFinder() bool { return true }

func (p *androidPlatform) FindConnectionOwner(r *adapter.FindConnectionOwnerRequest) (*adapter.ConnectionOwner, error) {
	find := ConnectionOwnerFinder
	if find == nil {
		return nil, process.ErrNotFound
	}
	uid, packages, ok := find(r.IpProtocol, r.SourceAddress, r.SourcePort, r.DestinationAddress, r.DestinationPort)
	if !ok {
		return nil, process.ErrNotFound
	}
	return &adapter.ConnectionOwner{UserId: uid, AndroidPackageNames: packages}, nil
}
func (p *androidPlatform) UsePlatformWIFIMonitor() bool                 { return false }
func (p *androidPlatform) UsePlatformNotification() bool                { return false }
func (p *androidPlatform) SendNotification(*adapter.Notification) error { return nil }
func (p *androidPlatform) CancelNotification(string, int32) error       { return nil }
func (p *androidPlatform) UsePlatformNeighborResolver() bool            { return false }
func (p *androidPlatform) StartNeighborMonitor(adapter.NeighborUpdateListener) error {
	return errors.ErrUnsupported
}
func (p *androidPlatform) CloseNeighborMonitor(adapter.NeighborUpdateListener) error { return nil }
func (p *androidPlatform) UsePlatformShell() bool                                    { return false }
func (p *androidPlatform) CheckPlatformShell() error                                 { return errors.ErrUnsupported }
func (p *androidPlatform) OpenShellSession(*adapter.PlatformUser, string, []string, string, int32, int32) (adapter.ShellSession, error) {
	return nil, errors.ErrUnsupported
}
func (p *androidPlatform) LookupUser(string) (*adapter.PlatformUser, error) {
	return nil, errors.ErrUnsupported
}
func (p *androidPlatform) LookupSFTPServer() (string, error)     { return "", errors.ErrUnsupported }
func (p *androidPlatform) ReadSystemSSHHostKey() ([]byte, error) { return nil, errors.ErrUnsupported }
func (p *androidPlatform) TailscaleHostname() string             { return "" }
func (p *androidPlatform) UsePlatformBridge() bool               { return false }
func (p *androidPlatform) CreateBridge(adapter.BridgeOptions) (adapter.BridgeSession, error) {
	return nil, errors.ErrUnsupported
}

func (p *androidPlatform) MyInterfaceAddress() []netip.Addr {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.myAddrs
}

// tunName asks the kernel for the interface name behind a TUN descriptor.
func tunName(fd int) (string, error) {
	var ifr [unix.IFNAMSIZ + 64]byte
	_, _, errno := unix.Syscall(unix.SYS_IOCTL, uintptr(fd), uintptr(unix.TUNGETIFF), uintptr(unsafe.Pointer(&ifr[0])))
	if errno != 0 {
		return "", syscall.Errno(errno)
	}
	return unix.ByteSliceToString(ifr[:unix.IFNAMSIZ]), nil
}

// androidMonitor reports the real network from SetDefaultInterface (fed by
// the app's ConnectivityManager callback) instead of netlink, which Android
// doesn't allow apps to watch.
type androidMonitor struct {
	p         *androidPlatform
	logger    logger.Logger
	mu        sync.Mutex
	current   *control.Interface
	callbacks list.List[tun.DefaultInterfaceUpdateCallback]
	mine      []string
	cancel    func()
}

func (m *androidMonitor) Start() error {
	m.cancel = watchDefaultInterface(m.update)
	m.update(currentDefaultInterface())
	return nil
}

func (m *androidMonitor) Close() error {
	if m.cancel != nil {
		m.cancel()
		m.cancel = nil
	}
	return nil
}

func (m *androidMonitor) update(d DefaultInterface) {
	m.mu.Lock()
	for _, mine := range m.mine {
		if d.Name != "" && d.Name == mine {
			m.mu.Unlock()
			return // our own VPN interface is never the way out
		}
	}
	m.mu.Unlock()
	var iface *control.Interface
	if d.Index >= 0 {
		if nm := m.p.networkManager(); nm != nil {
			if err := nm.UpdateInterfaces(); err != nil && m.logger != nil {
				m.logger.Debug("update interfaces: ", err)
			}
			if found, err := nm.InterfaceFinder().ByIndex(d.Index); err == nil {
				iface = found
			}
		}
		if iface == nil {
			iface = &control.Interface{Index: d.Index, Name: d.Name}
		}
	}
	m.mu.Lock()
	old := m.current
	m.current = iface
	same := (old == nil && iface == nil) || (old != nil && iface != nil && old.Index == iface.Index && old.Name == iface.Name)
	callbacks := m.callbacks.Array()
	m.mu.Unlock()
	if same {
		return
	}
	if m.logger != nil {
		if iface == nil {
			m.logger.Info("default interface: none")
		} else {
			m.logger.Info("default interface: ", iface.Name, " (index ", iface.Index, ")")
		}
	}
	for _, cb := range callbacks {
		cb(iface, 0)
	}
}

func (m *androidMonitor) DefaultInterface() *control.Interface {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.current
}

func (m *androidMonitor) OverrideAndroidVPN() bool { return false }
func (m *androidMonitor) AndroidVPNEnabled() bool  { return false }

func (m *androidMonitor) RegisterCallback(cb tun.DefaultInterfaceUpdateCallback) *list.Element[tun.DefaultInterfaceUpdateCallback] {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.callbacks.PushBack(cb)
}

func (m *androidMonitor) UnregisterCallback(e *list.Element[tun.DefaultInterfaceUpdateCallback]) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.callbacks.Remove(e)
}

func (m *androidMonitor) RegisterMyInterface(name string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.mine = append(m.mine, name)
}

func (m *androidMonitor) MyInterfaces() []string {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.mine
}
