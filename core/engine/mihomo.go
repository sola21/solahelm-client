package engine

import (
	"fmt"
	"os"
	"strings"

	"github.com/metacubex/mihomo/component/process"
	"github.com/metacubex/mihomo/config"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/hub"
	"github.com/metacubex/mihomo/hub/executor"
	"github.com/metacubex/mihomo/hub/route"
	"github.com/metacubex/mihomo/tunnel/statistic"
)

// mihomo keeps its state in package-level globals, so only one instance can
// exist per process. Manager guarantees that.
//
// Its cache.db (selected proxies, fake-ip pool) is opened once per process via
// sync.Once and never closed, so the first WorkDir wins for the cache and the
// file stays locked until the process exits. Use one fixed WorkDir per process.
type mihomoEngine struct {
	started bool
}

func (m *mihomoEngine) Kind() Kind { return Mihomo }

func (m *mihomoEngine) Start(raw []byte, opts Options) error {
	if opts.WorkDir != "" {
		if err := os.MkdirAll(opts.WorkDir, 0o755); err != nil {
			return err
		}
		constant.SetHomeDir(opts.WorkDir)
	}
	var hubOpts []hub.Option
	if opts.Controller != "" {
		hubOpts = append(hubOpts, hub.WithExternalController(opts.Controller), hub.WithSecret(opts.Secret))
	}
	if opts.ProxyOnly {
		hubOpts = append(hubOpts, func(c *config.Config) {
			c.General.Tun.Enable = false
			c.General.RedirPort = 0
			c.General.TProxyPort = 0
			if c.DNS != nil {
				c.DNS.Listen = "" // no local DNS server: only TUN would need it
			}
		})
	}
	if opts.ProxyOnly || opts.LoopbackOnly {
		hubOpts = append(hubOpts, func(c *config.Config) {
			c.General.AllowLan = false
			c.General.BindAddress = "127.0.0.1"
		})
	}
	if opts.FindProcess {
		hubOpts = append(hubOpts, func(c *config.Config) { c.General.FindProcessMode = process.FindProcessAlways })
	}
	if err := opts.Tuning.validate(); err != nil {
		return err
	}
	if opts.Tuning != nil {
		hubOpts = append(hubOpts, func(c *config.Config) { applyMihomoTuning(c, opts.Tuning) })
	}
	if opts.TUNStack != "" {
		stack, ok := constant.StackTypeMapping[strings.ToLower(opts.TUNStack)]
		if !ok {
			return fmt.Errorf("unknown TUN stack %q", opts.TUNStack)
		}
		hubOpts = append(hubOpts, func(c *config.Config) { c.General.Tun.Stack = stack })
	}
	if opts.MixedPort != 0 {
		hubOpts = append(hubOpts, func(c *config.Config) {
			c.General.MixedPort = opts.MixedPort
			c.General.Port = 0
			c.General.SocksPort = 0
		})
	}
	raw, err := injectMihomoRules(raw, opts.Rules)
	if err != nil {
		return err
	}
	if opts.Tuning != nil {
		if raw, err = injectMihomoDNS(raw, opts.Tuning.DNS); err != nil {
			return err
		}
	}
	if err := hub.Parse(raw, hubOpts...); err != nil {
		return err
	}
	m.started = true
	return nil
}

func (m *mihomoEngine) Stop() error {
	if !m.started {
		return nil
	}
	m.started = false
	// Close the API server, every listener (including TUN) and every live connection.
	route.ReCreateServer(&route.Config{})
	executor.Shutdown()
	statistic.DefaultManager.Range(func(c statistic.Tracker) bool {
		_ = c.Close()
		return true
	})
	return nil
}
