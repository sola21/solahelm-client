package daemon

import (
	"net"
	"strings"
	"testing"

	"golang.org/x/sys/windows/registry"
)

// The tests work on scratch keys, never on the real Internet Settings.
func scratchRegistry(t *testing.T) registry.Key {
	t.Helper()
	const root = `Software\SolaHelmTest`
	oldIS, oldBackup, oldRunOnce := internetSettings, backupKey, runOnceKey
	internetSettings, backupKey, runOnceKey = root+`\InternetSettings`, root+`\Backup`, root+`\RunOnce`
	cleanup := func() {
		for _, k := range []string{internetSettings, backupKey, runOnceKey, root} {
			_ = registry.DeleteKey(registry.CURRENT_USER, k)
		}
	}
	cleanup()
	t.Cleanup(func() {
		cleanup()
		internetSettings, backupKey, runOnceKey = oldIS, oldBackup, oldRunOnce
	})
	k, _, err := registry.CreateKey(registry.CURRENT_USER, internetSettings, registry.ALL_ACCESS)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { k.Close() })
	return k
}

// A local port with (or without) something listening on it.
func localPort(t *testing.T) (addr string, stop func()) {
	t.Helper()
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	go func() {
		for {
			c, err := l.Accept()
			if err != nil {
				return
			}
			c.Close()
		}
	}()
	return l.Addr().String(), func() { l.Close() }
}

var userSetup = proxySnapshot{enable: 1, server: "10.1.2.3:3128", override: "intranet.*", autoURL: "http://wpad.example.org/proxy.pac", hasAuto: true}

func hasRunOnce(t *testing.T) bool {
	t.Helper()
	k, err := registry.OpenKey(registry.CURRENT_USER, runOnceKey, registry.QUERY_VALUE)
	if err != nil {
		return false
	}
	defer k.Close()
	v, _, err := k.GetStringValue(runOnceValue)
	return err == nil && strings.HasSuffix(v, " restore-proxy")
}

func backupExists() bool {
	_, _, ok := loadBackup()
	return ok
}

func TestSystemProxyCleanDisconnect(t *testing.T) {
	k := scratchRegistry(t)
	if err := writeSettings(k, userSetup); err != nil {
		t.Fatal(err)
	}
	addr, stop := localPort(t)
	defer stop()
	p := &winSystemProxy{}
	if err := p.Enable(addr, nil); err != nil {
		t.Fatal(err)
	}
	cur := readSettings(k)
	if cur.enable != 1 || cur.server != addr || cur.hasAuto {
		t.Fatalf("while connected: %+v", cur)
	}
	if !backupExists() || !hasRunOnce(t) {
		t.Fatal("the user's setup must be kept in the registry while connected")
	}
	if err := p.Disable(); err != nil {
		t.Fatal(err)
	}
	if cur := readSettings(k); cur != userSetup {
		t.Fatalf("after disconnect: %+v, want %+v", cur, userSetup)
	}
	if backupExists() || hasRunOnce(t) {
		t.Fatal("a clean disconnect leaves no backup and no RunOnce entry")
	}
}

// The core died (crash, PC shutdown, killed): the next start puts things back.
func TestSystemProxyRecoverAfterDeath(t *testing.T) {
	k := scratchRegistry(t)
	_ = writeSettings(k, userSetup)
	addr, stop := localPort(t)
	if err := (&winSystemProxy{}).Enable(addr, nil); err != nil {
		t.Fatal(err)
	}
	stop() // the core is gone, its port is closed
	ok, err := RecoverSystemProxy()
	if err != nil || !ok {
		t.Fatalf("recover: %v %v", ok, err)
	}
	if cur := readSettings(k); cur != userSetup {
		t.Fatalf("after recovery: %+v", cur)
	}
	if backupExists() || hasRunOnce(t) {
		t.Fatal("recovery clears the backup")
	}
	if ok, _ := RecoverSystemProxy(); ok {
		t.Fatal("nothing left to recover")
	}
}

// "Exit, keep the VPN on": the core still listens, so its proxy stays.
func TestSystemProxyRecoverLeavesALiveCore(t *testing.T) {
	k := scratchRegistry(t)
	_ = writeSettings(k, userSetup)
	addr, stop := localPort(t)
	defer stop()
	if err := (&winSystemProxy{}).Enable(addr, nil); err != nil {
		t.Fatal(err)
	}
	if ok, err := RecoverSystemProxy(); ok || err != nil {
		t.Fatalf("recover: %v %v", ok, err)
	}
	if cur := readSettings(k); cur.server != addr || !backupExists() {
		t.Fatal("a live core's proxy must stay")
	}
}

// The user changed the proxy settings after the core died: leave them be.
func TestSystemProxyRecoverRespectsUserChanges(t *testing.T) {
	k := scratchRegistry(t)
	_ = writeSettings(k, userSetup)
	addr, stop := localPort(t)
	_ = (&winSystemProxy{}).Enable(addr, nil)
	stop()
	_ = k.SetDWordValue("ProxyEnable", 0)
	if ok, err := RecoverSystemProxy(); ok || err != nil {
		t.Fatalf("recover: %v %v", ok, err)
	}
	if cur := readSettings(k); cur.enable != 0 || cur.server != addr {
		t.Fatalf("the user's change must stay: %+v", cur)
	}
	if backupExists() {
		t.Fatal("the stale backup is dropped")
	}
}

// Older versions kept the backup in memory only: a proxy they left behind
// must not be taken for the user's own setup.
func TestSystemProxyOldLeftover(t *testing.T) {
	k := scratchRegistry(t)
	dead, stop := localPort(t)
	stop()
	_ = writeSettings(k, proxySnapshot{enable: 1, server: dead, override: strings.Join(DefaultBypass, ";")})
	addr, stop2 := localPort(t)
	defer stop2()
	p := &winSystemProxy{}
	if err := p.Enable(addr, nil); err != nil {
		t.Fatal(err)
	}
	if err := p.Disable(); err != nil {
		t.Fatal(err)
	}
	if cur := readSettings(k); cur.enable != 0 {
		t.Fatalf("the leftover must be switched off, got %+v", cur)
	}
}

// Connecting again after a crash (without a recovery in between) still ends
// with the user's own setup, not with the dead core's proxy.
func TestSystemProxyReconnectAfterDeath(t *testing.T) {
	k := scratchRegistry(t)
	_ = writeSettings(k, userSetup)
	a1, stop1 := localPort(t)
	_ = (&winSystemProxy{}).Enable(a1, nil)
	stop1()
	a2, stop2 := localPort(t)
	defer stop2()
	p := &winSystemProxy{}
	if err := p.Enable(a2, nil); err != nil {
		t.Fatal(err)
	}
	if err := p.Disable(); err != nil {
		t.Fatal(err)
	}
	if cur := readSettings(k); cur != userSetup {
		t.Fatalf("after reconnect + disconnect: %+v", cur)
	}
}
