package engine

import (
	"fmt"
	"net/netip"
	"strings"

	"github.com/metacubex/mihomo/config"
	mlog "github.com/metacubex/mihomo/log"
	C "github.com/sagernet/sing-box/constant"
	"github.com/sagernet/sing-box/option"
	"github.com/sagernet/sing/common/json/badoption"
	"go.yaml.in/yaml/v3"
)

// Tuning overrides a profile's settings with the user's app settings. Zero
// values leave the profile alone.
type Tuning struct {
	// TUN (applied only when the profile runs with TUN).
	StrictRoute  *bool    `json:"strictRoute,omitempty"`
	MTU          uint32   `json:"mtu,omitempty"`
	RouteExclude []string `json:"routeExclude,omitempty"` // CIDRs that bypass the tunnel
	// IPv6 on/off for the whole profile; nil keeps the profile's choice.
	IPv6 *bool `json:"ipv6,omitempty"`
	// LogLevel: debug, info, warning, error, silent; "" keeps the profile's.
	LogLevel string `json:"logLevel,omitempty"`
	// AllowLAN makes the local proxy port reachable from other devices.
	AllowLAN bool `json:"allowLan,omitempty"`
	// DNS replaces the profile's DNS servers (mihomo profiles only).
	DNS *DNSOverride `json:"dns,omitempty"`
}

// DNS modes of a DNSOverride.
const (
	// DNSModeVPN: Remote servers through the tunnel (queries follow the
	// routing rules), Direct servers for the proxy servers and direct traffic.
	DNSModeVPN = "vpn"
	// DNSModeDirect: every query goes to the Direct servers, not through the VPN.
	DNSModeDirect = "direct"
	// DNSModeSystem: every query goes to the resolvers of the OS / network,
	// not through the VPN (the core's own TUN DNS is excluded).
	DNSModeSystem = "system"
)

// DNSOverride sets the resolvers of a mihomo profile.
type DNSOverride struct {
	Mode   string   `json:"mode,omitempty"` // "" = DNSModeVPN
	Remote []string `json:"remote"`         // e.g. https://1.1.1.1/dns-query
	Direct []string `json:"direct"`         // plain IPs, e.g. 77.88.8.8
}

func (d *DNSOverride) mode() string {
	if d.Mode == "" {
		return DNSModeVPN
	}
	return d.Mode
}

func (d *DNSOverride) validate() error {
	if d == nil {
		return nil
	}
	switch d.mode() {
	case DNSModeVPN:
		if len(d.Remote) == 0 || len(d.Direct) == 0 {
			return fmt.Errorf("DNS through the VPN needs remote and direct servers")
		}
	case DNSModeDirect:
		if len(d.Direct) == 0 {
			return fmt.Errorf("direct DNS needs at least one server")
		}
	case DNSModeSystem:
	default:
		return fmt.Errorf("unknown DNS mode %q", d.Mode)
	}
	return nil
}

func (t *Tuning) parseExclude() ([]netip.Prefix, error) {
	var out []netip.Prefix
	for _, s := range t.RouteExclude {
		s = strings.TrimSpace(s)
		if s == "" {
			continue
		}
		p, err := netip.ParsePrefix(s)
		if err != nil {
			return nil, fmt.Errorf("excluded network %q: %w", s, err)
		}
		out = append(out, p)
	}
	return out, nil
}

var logLevels = map[string]bool{"debug": true, "info": true, "warning": true, "error": true, "silent": true}

func (t *Tuning) validate() error {
	if t == nil {
		return nil
	}
	if t.LogLevel != "" && !logLevels[t.LogLevel] {
		return fmt.Errorf("unknown log level %q", t.LogLevel)
	}
	if t.MTU != 0 && (t.MTU < 576 || t.MTU > 65535) {
		return fmt.Errorf("MTU %d is out of range 576..65535", t.MTU)
	}
	if _, err := t.parseExclude(); err != nil {
		return err
	}
	return t.DNS.validate()
}

// applyMihomoTuning changes the parsed mihomo config.
func applyMihomoTuning(c *config.Config, t *Tuning) {
	if t == nil {
		return
	}
	if t.StrictRoute != nil {
		c.General.Tun.StrictRoute = *t.StrictRoute
	}
	if t.MTU != 0 {
		c.General.Tun.MTU = t.MTU
	}
	if ex, _ := t.parseExclude(); len(ex) > 0 {
		c.General.Tun.RouteExcludeAddress = append(c.General.Tun.RouteExcludeAddress, ex...)
	}
	if t.IPv6 != nil {
		c.General.IPv6 = *t.IPv6
		if c.DNS != nil {
			c.DNS.IPv6 = *t.IPv6
		}
		if !*t.IPv6 {
			c.General.Tun.Inet6Address = nil
		}
	}
	if t.LogLevel != "" {
		if lvl, ok := mlog.LogLevelMapping[t.LogLevel]; ok {
			c.General.LogLevel = lvl
		}
	}
	if t.AllowLAN {
		c.General.AllowLan = true
		c.General.BindAddress = "*"
	}
}

// applySingBoxTuning changes the parsed sing-box options.
func applySingBoxTuning(o *option.Options, t *Tuning) {
	if t == nil {
		return
	}
	ex, _ := t.parseExclude()
	if t.AllowLAN {
		any4 := badoption.Addr(netip.IPv4Unspecified())
		for _, in := range o.Inbounds {
			if in.Type != C.TypeMixed && in.Type != C.TypeSOCKS && in.Type != C.TypeHTTP {
				continue
			}
			if w, ok := in.Options.(option.ListenOptionsWrapper); ok {
				l := w.TakeListenOptions()
				l.Listen = &any4
				w.ReplaceListenOptions(l)
			}
		}
	}
	for _, in := range o.Inbounds {
		tun, ok := in.Options.(*option.TunInboundOptions)
		if !ok {
			continue
		}
		if t.StrictRoute != nil {
			tun.StrictRoute = *t.StrictRoute
		}
		if t.MTU != 0 {
			tun.MTU = t.MTU
		}
		if len(ex) > 0 {
			tun.RouteExcludeAddress = append(tun.RouteExcludeAddress, ex...)
		}
		if t.IPv6 != nil && !*t.IPv6 {
			var v4 badoption.Listable[netip.Prefix]
			for _, a := range tun.Address {
				if a.Addr().Is4() {
					v4 = append(v4, a)
				}
			}
			tun.Address = v4
		}
	}
	if t.IPv6 != nil && o.DNS != nil {
		if *t.IPv6 {
			if o.DNS.Strategy == option.DomainStrategy(C.DomainStrategyIPv4Only) {
				o.DNS.Strategy = option.DomainStrategy(C.DomainStrategyAsIS)
			}
		} else {
			o.DNS.Strategy = option.DomainStrategy(C.DomainStrategyIPv4Only)
		}
	}
	if t.LogLevel != "" {
		if o.Log == nil {
			o.Log = &option.LogOptions{}
		}
		if t.LogLevel == "silent" {
			o.Log.Disabled = true
		} else {
			o.Log.Disabled = false
			o.Log.Level = map[string]string{"debug": "debug", "info": "info", "warning": "warn", "error": "error"}[t.LogLevel]
		}
	}
}

// injectMihomoDNS rewrites the dns section of a mihomo YAML config.
func injectMihomoDNS(raw []byte, d *DNSOverride) ([]byte, error) {
	if d == nil || d.validate() != nil {
		return raw, nil
	}
	var cfg map[string]any
	if err := yaml.Unmarshal(raw, &cfg); err != nil {
		return nil, err
	}
	dns, _ := cfg["dns"].(map[string]any)
	if dns == nil {
		dns = map[string]any{"enhanced-mode": "fake-ip", "fake-ip-range": "198.18.0.1/16"}
	}
	dns["enable"] = true
	dns["prefer-h3"] = false // HTTP/3 to public resolvers is often throttled; plain DoH is steadier
	delete(dns, "fallback")
	delete(dns, "fallback-filter")
	switch d.mode() {
	case DNSModeVPN:
		dns["respect-rules"] = true
		dns["nameserver"] = d.Remote
		dns["default-nameserver"] = d.Direct
		dns["proxy-server-nameserver"] = d.Direct
		dns["direct-nameserver"] = d.Direct
	case DNSModeDirect, DNSModeSystem:
		servers := d.Direct
		if d.mode() == DNSModeSystem {
			servers = []string{"system"}
		}
		// Every query to these servers, around the VPN: no per-domain policies
		// of the profile that would send some of them elsewhere.
		dns["respect-rules"] = false
		dns["nameserver"] = servers
		dns["proxy-server-nameserver"] = servers
		dns["direct-nameserver"] = servers
		if len(d.Direct) > 0 {
			dns["default-nameserver"] = d.Direct
		} else {
			delete(dns, "default-nameserver")
		}
		delete(dns, "nameserver-policy")
		delete(dns, "direct-nameserver-follow-policy")
	}
	cfg["dns"] = dns
	return yaml.Marshal(cfg)
}
