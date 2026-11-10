package engine

import (
	"fmt"
	"os"
	"path/filepath"
	"testing"

	"github.com/metacubex/mihomo/listener"
	LC "github.com/metacubex/mihomo/listener/config"
)

// Regression (Windows, TUN mode): saving rules reconnects, i.e. stops and
// starts mihomo again in the same process. Stop used to leave the old TUN
// settings in listener.LastTunConf, so the new start saw "TUN unchanged" and
// never created the adapter: connected, but no traffic at all.
// Real TUN needs admin rights, so this checks the state mihomo decides on.
func TestMihomoStopForgetsTUN(t *testing.T) {
	workDir, err := os.MkdirTemp("", "solahelm-tunstate-test-")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(workDir)

	cfg := []byte(fmt.Sprintf("mixed-port: %d\nbind-address: 127.0.0.1\nallow-lan: false\nlog-level: warning\nmode: rule\nproxies: []\nrules:\n  - MATCH,DIRECT\n", freePort(t)))
	var m Manager
	defer m.Stop()
	if err := m.Start(Mihomo, cfg, Options{WorkDir: filepath.Join(workDir, "mihomo"), ProxyOnly: true}); err != nil {
		t.Fatal(err)
	}
	// What a TUN-mode start leaves behind.
	listener.LastTunConf = LC.Tun{Enable: true, Device: "SolaHelm", Stack: 1, AutoRoute: true}

	if err := m.Stop(); err != nil {
		t.Fatal(err)
	}
	if listener.LastTunConf.Enable {
		t.Fatal("mihomo still remembers an enabled TUN after Stop: the next start would skip creating it")
	}
}
