package daemon

import (
	"fmt"
	"strings"
	"syscall"

	"golang.org/x/sys/windows/registry"
)

const internetSettings = `Software\Microsoft\Windows\CurrentVersion\Internet Settings`

// proxySnapshot is the user's WinINet proxy setup before we changed it.
type proxySnapshot struct {
	enable   uint64
	server   string
	override string
	autoURL  string
	hasAuto  bool
}

type winSystemProxy struct {
	saved *proxySnapshot
}

func newSystemProxy() systemProxy { return &winSystemProxy{} }

// DefaultBypass is used when the app sends no exception list.
var DefaultBypass = []string{
	"localhost", "127.*", "10.*", "172.16.*", "172.17.*", "172.18.*", "172.19.*", "172.2*", "172.30.*", "172.31.*",
	"192.168.*", "<local>",
}

func (p *winSystemProxy) Enable(addr string, bypass []string) error {
	if len(bypass) == 0 {
		bypass = DefaultBypass
	}
	k, err := registry.OpenKey(registry.CURRENT_USER, internetSettings, registry.QUERY_VALUE|registry.SET_VALUE)
	if err != nil {
		return err
	}
	defer k.Close()
	if p.saved == nil {
		s := &proxySnapshot{}
		s.enable, _, _ = k.GetIntegerValue("ProxyEnable")
		s.server, _, _ = k.GetStringValue("ProxyServer")
		s.override, _, _ = k.GetStringValue("ProxyOverride")
		if v, _, err := k.GetStringValue("AutoConfigURL"); err == nil {
			s.autoURL, s.hasAuto = v, true
		}
		p.saved = s
	}
	if err := k.SetDWordValue("ProxyEnable", 1); err != nil {
		return err
	}
	if err := k.SetStringValue("ProxyServer", addr); err != nil {
		return err
	}
	if err := k.SetStringValue("ProxyOverride", strings.Join(bypass, ";")); err != nil {
		return err
	}
	if p.saved.hasAuto {
		_ = k.DeleteValue("AutoConfigURL")
	}
	return notifyProxyChanged()
}

func (p *winSystemProxy) Disable() error {
	s := p.saved
	if s == nil {
		return nil
	}
	k, err := registry.OpenKey(registry.CURRENT_USER, internetSettings, registry.SET_VALUE)
	if err != nil {
		return err
	}
	defer k.Close()
	errs := []error{
		k.SetDWordValue("ProxyEnable", uint32(s.enable)),
		k.SetStringValue("ProxyServer", s.server),
		k.SetStringValue("ProxyOverride", s.override),
	}
	if s.hasAuto {
		errs = append(errs, k.SetStringValue("AutoConfigURL", s.autoURL))
	}
	p.saved = nil
	for _, e := range errs {
		if e != nil {
			return e
		}
	}
	return notifyProxyChanged()
}

var (
	wininet               = syscall.NewLazyDLL("wininet.dll")
	procInternetSetOption = wininet.NewProc("InternetSetOptionW")
)

// Tells WinINet (and so browsers using system settings) to re-read the registry.
func notifyProxyChanged() error {
	const settingsChanged, refresh = 39, 37
	for _, opt := range []uintptr{settingsChanged, refresh} {
		r, _, err := procInternetSetOption.Call(0, opt, 0, 0)
		if r == 0 {
			return fmt.Errorf("InternetSetOption(%d): %w", opt, err)
		}
	}
	return nil
}
