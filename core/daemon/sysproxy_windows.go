package daemon

import (
	"fmt"
	"net"
	"os"
	"strings"
	"syscall"
	"time"

	"golang.org/x/sys/windows/registry"
)

// The system proxy mode points WinINet (Settings → Proxy, "Use a proxy
// server") at the core's local port and puts the user's own settings back on
// disconnect. If the core dies without that (PC shutdown, a crash, killed by
// an installer or Task Manager), Windows keeps pointing at a port nobody
// listens on and the internet "breaks". So the user's settings are also kept
// in the registry (backupKey) while the proxy is ours:
//   - RecoverSystemProxy (every core start, and "solahelm-core restore-proxy")
//     puts them back when the proxy still points at our dead port;
//   - a RunOnce entry runs restore-proxy at the next Windows sign-in, so a
//     shutdown while connected doesn't leave the next session offline even
//     when the app isn't started.

// Registry locations; variables so tests can use scratch keys.
var (
	internetSettings = `Software\Microsoft\Windows\CurrentVersion\Internet Settings`
	backupKey        = `Software\SolaHelm\SystemProxy`
	runOnceKey       = `Software\Microsoft\Windows\CurrentVersion\RunOnce`
)

const runOnceValue = "SolaHelmRestoreProxy"

// proxySnapshot is a WinINet proxy setup.
type proxySnapshot struct {
	enable   uint64
	server   string
	override string
	autoURL  string
	hasAuto  bool
}

type winSystemProxy struct {
	saved *proxySnapshot // the user's own setup, put back by Disable
}

func newSystemProxy() systemProxy { return &winSystemProxy{} }

// DefaultBypass is used when the app sends no exception list.
var DefaultBypass = []string{
	"localhost", "127.*", "10.*", "172.16.*", "172.17.*", "172.18.*", "172.19.*", "172.2*", "172.30.*", "172.31.*",
	"192.168.*", "<local>",
}

func readSettings(k registry.Key) proxySnapshot {
	var s proxySnapshot
	s.enable, _, _ = k.GetIntegerValue("ProxyEnable")
	s.server, _, _ = k.GetStringValue("ProxyServer")
	s.override, _, _ = k.GetStringValue("ProxyOverride")
	if v, _, err := k.GetStringValue("AutoConfigURL"); err == nil {
		s.autoURL, s.hasAuto = v, true
	}
	return s
}

func writeSettings(k registry.Key, s proxySnapshot) error {
	errs := []error{
		k.SetDWordValue("ProxyEnable", uint32(s.enable)),
		k.SetStringValue("ProxyServer", s.server),
		k.SetStringValue("ProxyOverride", s.override),
	}
	if s.hasAuto {
		errs = append(errs, k.SetStringValue("AutoConfigURL", s.autoURL))
	}
	for _, e := range errs {
		if e != nil {
			return e
		}
	}
	return nil
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
		s, _, ok := loadBackup()
		if !ok {
			// No backup: what's set now is the user's own setup, unless it is
			// what an older version left behind after dying (it kept the
			// backup in memory only): then the user's setup was "no proxy".
			s = readSettings(k)
			if leftover(s, addr, bypass) {
				s = proxySnapshot{}
			}
		}
		p.saved = &s
	}
	if err := saveBackup(*p.saved, addr); err != nil {
		return err
	}
	setRunOnce()
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

// leftover reports whether s is our own proxy setting from a core that is
// gone: our address now, or a local port nobody listens on with our list of
// exceptions.
func leftover(s proxySnapshot, addr string, bypass []string) bool {
	if s.enable != 1 || !strings.HasPrefix(s.server, "127.0.0.1:") {
		return false
	}
	if s.server == addr {
		return true
	}
	ours := s.override == strings.Join(bypass, ";") || s.override == strings.Join(DefaultBypass, ";")
	return ours && !listening(s.server)
}

func listening(addr string) bool {
	c, err := net.DialTimeout("tcp", addr, 500*time.Millisecond)
	if err != nil {
		return false
	}
	_ = c.Close()
	return true
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
	err = writeSettings(k, *s)
	p.saved = nil
	if err != nil {
		return err
	}
	dropBackup()
	return notifyProxyChanged()
}

// RecoverSystemProxy puts the user's proxy settings back after a core that
// had set them died without doing so. It leaves everything alone while some
// process still listens on that address (a core kept running on purpose) and
// when the user has changed the settings since. Reports whether it restored.
func RecoverSystemProxy() (bool, error) {
	saved, ours, ok := loadBackup()
	if !ok {
		return false, nil
	}
	k, err := registry.OpenKey(registry.CURRENT_USER, internetSettings, registry.QUERY_VALUE|registry.SET_VALUE)
	if err != nil {
		return false, err
	}
	defer k.Close()
	cur := readSettings(k)
	stillOurs := cur.enable == 1 && cur.server == ours
	if stillOurs && listening(ours) {
		return false, nil // a running core still uses it
	}
	restored := false
	if stillOurs {
		if err := writeSettings(k, saved); err != nil {
			return false, err
		}
		restored = true
	}
	dropBackup()
	if restored {
		return true, notifyProxyChanged()
	}
	return false, nil
}

func saveBackup(s proxySnapshot, ours string) error {
	k, _, err := registry.CreateKey(registry.CURRENT_USER, backupKey, registry.SET_VALUE)
	if err != nil {
		return err
	}
	defer k.Close()
	hasAuto := uint32(0)
	if s.hasAuto {
		hasAuto = 1
	}
	for _, e := range []error{
		k.SetDWordValue("ProxyEnable", uint32(s.enable)),
		k.SetStringValue("ProxyServer", s.server),
		k.SetStringValue("ProxyOverride", s.override),
		k.SetStringValue("AutoConfigURL", s.autoURL),
		k.SetDWordValue("HasAutoConfigURL", hasAuto),
		k.SetStringValue("Ours", ours),
	} {
		if e != nil {
			return e
		}
	}
	return nil
}

func loadBackup() (s proxySnapshot, ours string, ok bool) {
	k, err := registry.OpenKey(registry.CURRENT_USER, backupKey, registry.QUERY_VALUE)
	if err != nil {
		return s, "", false
	}
	defer k.Close()
	ours, _, err = k.GetStringValue("Ours")
	if err != nil || ours == "" {
		return s, "", false
	}
	s.enable, _, _ = k.GetIntegerValue("ProxyEnable")
	s.server, _, _ = k.GetStringValue("ProxyServer")
	s.override, _, _ = k.GetStringValue("ProxyOverride")
	s.autoURL, _, _ = k.GetStringValue("AutoConfigURL")
	h, _, _ := k.GetIntegerValue("HasAutoConfigURL")
	s.hasAuto = h == 1
	return s, ours, true
}

func dropBackup() {
	_ = registry.DeleteKey(registry.CURRENT_USER, backupKey)
	if k, err := registry.OpenKey(registry.CURRENT_USER, runOnceKey, registry.SET_VALUE); err == nil {
		_ = k.DeleteValue(runOnceValue)
		k.Close()
	}
}

// setRunOnce asks Windows to run "restore-proxy" at the next sign-in; a clean
// disconnect removes the entry again.
func setRunOnce() {
	exe, err := os.Executable()
	if err != nil {
		return
	}
	k, _, err := registry.CreateKey(registry.CURRENT_USER, runOnceKey, registry.SET_VALUE)
	if err != nil {
		return
	}
	defer k.Close()
	_ = k.SetStringValue(runOnceValue, fmt.Sprintf(`"%s" restore-proxy`, exe))
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
