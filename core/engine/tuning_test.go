package engine

import (
	"context"
	"github.com/metacubex/mihomo/config"
	"net/netip"
	"testing"

	"github.com/metacubex/mihomo/hub/executor"
	mlog "github.com/metacubex/mihomo/log"
	C "github.com/sagernet/sing-box/constant"
	"github.com/sagernet/sing-box/include"
	"github.com/sagernet/sing-box/option"
	"github.com/sagernet/sing/common/json"
)

func boolp(b bool) *bool { return &b }

func TestTuningSingBox(t *testing.T) {
	raw := []byte(`{
  "log": {"level": "warn"},
  "dns": {"servers": [{"type": "local", "tag": "local"}]},
  "inbounds": [
    {"type": "tun", "tag": "tun-in", "address": ["172.19.0.1/30", "fdfe:dcba:9876::1/126"], "auto_route": true},
    {"type": "mixed", "tag": "mixed-in", "listen": "127.0.0.1", "listen_port": 2080}
  ],
  "outbounds": [{"type": "direct", "tag": "direct"}]
}`)
	o, err := json.UnmarshalExtendedContext[option.Options](include.Context(context.Background()), raw)
	if err != nil {
		t.Fatal(err)
	}
	tune := &Tuning{StrictRoute: boolp(true), MTU: 1400, RouteExclude: []string{"192.168.0.0/16"},
		IPv6: boolp(false), LogLevel: "debug", AllowLAN: true}
	if err := tune.validate(); err != nil {
		t.Fatal(err)
	}
	applySingBoxTuning(&o, tune)
	tun := o.Inbounds[0].Options.(*option.TunInboundOptions)
	if !tun.StrictRoute || tun.MTU != 1400 || len(tun.RouteExcludeAddress) != 1 || len(tun.Address) != 1 {
		t.Fatalf("tun: strict=%v mtu=%d exclude=%v addr=%v", tun.StrictRoute, tun.MTU, tun.RouteExcludeAddress, tun.Address)
	}
	if o.DNS.Strategy != option.DomainStrategy(C.DomainStrategyIPv4Only) || o.Log.Level != "debug" {
		t.Fatalf("dns strategy %v, log %q", o.DNS.Strategy, o.Log.Level)
	}
	mixed := o.Inbounds[1].Options.(*option.HTTPMixedInboundOptions)
	if mixed.Listen == nil || !netip.Addr(*mixed.Listen).IsUnspecified() {
		t.Fatalf("allow LAN: mixed listens on %v", mixed.Listen)
	}
}

func TestTuningMihomo(t *testing.T) {
	cfg, err := executor.ParseWithBytes([]byte("mixed-port: 7890\nipv6: true\nlog-level: warning\n" +
		"tun:\n  enable: true\n  stack: gvisor\n  mtu: 9000\n  strict-route: false\nproxies: []\nrules:\n  - MATCH,DIRECT\n"))
	if err != nil {
		t.Fatal(err)
	}
	applyMihomoTuning(cfg, &Tuning{StrictRoute: boolp(true), MTU: 1500, RouteExclude: []string{"10.0.0.0/8"},
		IPv6: boolp(false), LogLevel: "error", AllowLAN: true})
	g := cfg.General
	if !g.Tun.StrictRoute || g.Tun.MTU != 1500 || len(g.Tun.RouteExcludeAddress) != 1 || g.IPv6 ||
		g.LogLevel != mlog.ERROR || !g.AllowLan || g.BindAddress != "*" {
		t.Fatalf("mihomo tuning not applied: %+v", g)
	}
}

func TestTuningValidate(t *testing.T) {
	for _, bad := range []*Tuning{{LogLevel: "loud"}, {MTU: 100}, {RouteExclude: []string{"10.0.0.0"}}} {
		if bad.validate() == nil {
			t.Errorf("accepted %+v", bad)
		}
	}
}

func TestMihomoDNSOverride(t *testing.T) {
	raw := []byte("dns:\n  enable: true\n  prefer-h3: true\n  enhanced-mode: redir-host\n  nameserver: [https://cloudflare-dns.com/dns-query]\n  fallback: [tls://8.8.4.4]\nproxies: []\nrules:\n  - MATCH,DIRECT\n")
	out, err := injectMihomoDNS(raw, &DNSOverride{Remote: []string{"https://1.1.1.1/dns-query"}, Direct: []string{"77.88.8.8"}})
	if err != nil {
		t.Fatal(err)
	}
	cfg, err := executor.ParseWithBytes(out)
	if err != nil {
		t.Fatal(err)
	}
	d := cfg.DNS
	if d.PreferH3 || len(d.NameServer) != 1 || len(d.Fallback) != 0 || len(d.ProxyServerNameserver) != 1 {
		t.Fatalf("dns not overridden: h3=%v ns=%v fb=%v", d.PreferH3, d.NameServer, d.Fallback)
	}
	if d.NameServer[0].ProxyName == "" {
		t.Fatal("remote DNS should follow the rules (respect-rules)")
	}
}

func TestMihomoDNSModes(t *testing.T) {
	raw := []byte("dns:\n  enable: true\n  enhanced-mode: fake-ip\n  respect-rules: true\n" +
		"  nameserver: ['https://1.1.1.1/dns-query#Proxy']\n  nameserver-policy:\n    '+.example.com': ['https://8.8.8.8/dns-query']\n" +
		"proxies: []\nproxy-groups:\n  - {name: Proxy, type: select, proxies: [DIRECT]}\nrules:\n  - MATCH,Proxy\n")
	parse := func(d *DNSOverride) *config.Config {
		t.Helper()
		out, err := injectMihomoDNS(raw, d)
		if err != nil {
			t.Fatal(err)
		}
		cfg, err := executor.ParseWithBytes(out)
		if err != nil {
			t.Fatalf("%s: %v", d.Mode, err)
		}
		return cfg
	}

	// Direct: the user's servers, not through the VPN, no per-domain policy of the profile.
	c := parse(&DNSOverride{Mode: DNSModeDirect, Direct: []string{"77.88.8.8", "1.1.1.1"}})
	if len(c.DNS.NameServer) != 2 || c.DNS.NameServer[0].ProxyName != "" || c.DNS.NameServer[0].Addr != "77.88.8.8:53" {
		t.Fatalf("direct: %+v", c.DNS.NameServer)
	}
	if len(c.DNS.NameServerPolicy) != 0 {
		t.Fatalf("direct: the profile's nameserver-policy should be dropped: %+v", c.DNS.NameServerPolicy)
	}

	// System: the OS resolvers.
	c = parse(&DNSOverride{Mode: DNSModeSystem})
	if len(c.DNS.NameServer) != 1 || c.DNS.NameServer[0].Net != "system" || c.DNS.NameServer[0].ProxyName != "" {
		t.Fatalf("system: %+v", c.DNS.NameServer)
	}

	// Invalid settings are refused up front and never half-applied.
	for _, bad := range []*DNSOverride{{Mode: "bogus"}, {Mode: DNSModeDirect}, {Mode: DNSModeVPN, Direct: []string{"1.1.1.1"}}} {
		if (&Tuning{DNS: bad}).validate() == nil {
			t.Fatalf("accepted %+v", bad)
		}
	}
}
