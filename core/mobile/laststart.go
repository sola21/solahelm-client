package mobile

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"

	"github.com/sola21/solahelm-client/core/daemon"
)

// The quick-settings tile starts the VPN without the Flutter UI: it repeats
// the last start the app made (same profile, mode, rules and settings).

const lastStartFile = "last-start.json"

func lastStartPath() string { return filepath.Join(workDir, lastStartFile) }

func saveLastStart(req daemon.StartRequest) {
	req.TunFD = 0 // a descriptor means nothing next time
	b, err := json.Marshal(req)
	if err != nil {
		return
	}
	tmp := lastStartPath() + ".tmp"
	if os.WriteFile(tmp, b, 0o600) == nil {
		_ = os.Rename(tmp, lastStartPath())
	}
}

func loadLastStart() (daemon.StartRequest, error) {
	var req daemon.StartRequest
	b, err := os.ReadFile(lastStartPath())
	if err != nil {
		return req, errors.New("nothing to start yet: connect once from the app")
	}
	err = json.Unmarshal(b, &req)
	return req, err
}

// LastStart describes the start the tile would repeat as JSON
// {"mode":"tun","mtu":1500}, or "" when there is none.
func LastStart() string {
	mu.Lock()
	ready := srv != nil
	mu.Unlock()
	if !ready {
		return ""
	}
	req, err := loadLastStart()
	if err != nil {
		return ""
	}
	mtu := 0
	if req.Tuning != nil {
		mtu = int(req.Tuning.MTU)
	}
	b, _ := json.Marshal(map[string]any{"mode": req.Mode, "mtu": mtu})
	return string(b)
}

// StartLast starts the core again as the app last did; tunFD is the VPN
// interface for TUN mode (0 otherwise).
func StartLast(tunFD int32) error {
	mu.Lock()
	s := srv
	mu.Unlock()
	if s == nil {
		return errors.New("the core service is not running")
	}
	req, err := loadLastStart()
	if err != nil {
		return err
	}
	if req.Mode == daemon.ModeTUN && tunFD <= 0 {
		return errors.New("TUN mode needs the VPN interface")
	}
	req.TunFD = int(tunFD)
	_, err = s.Start(req)
	return err
}

// StopCore stops the running core but keeps the control service.
func StopCore() {
	mu.Lock()
	s := srv
	mu.Unlock()
	if s != nil {
		s.Stop()
	}
}

// Running reports whether a core is running.
func Running() bool {
	mu.Lock()
	s := srv
	mu.Unlock()
	return s != nil && s.Running()
}
