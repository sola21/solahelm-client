package engine

import (
	"testing"

	C "github.com/sagernet/sing-box/constant"
	"github.com/sagernet/sing-box/option"
)

func TestUseAndroidTun(t *testing.T) {
	o := option.Options{
		Inbounds: []option.Inbound{
			{Type: C.TypeTun, Tag: "a", Options: &option.TunInboundOptions{AutoRoute: true, StrictRoute: true, MTU: 9000, InterfaceName: "Meta"}},
			{Type: C.TypeTun, Tag: "b", Options: &option.TunInboundOptions{}},
			{Type: C.TypeMixed, Tag: "m", Options: &option.HTTPMixedInboundOptions{}},
		},
		Route: &option.RouteOptions{DefaultInterface: "Ethernet"},
	}
	useAndroidTun(&o, Options{TunFD: 3})
	if len(o.Inbounds) != 2 {
		t.Fatalf("want 1 tun + mixed, got %d inbounds", len(o.Inbounds))
	}
	tun := o.Inbounds[0].Options.(*option.TunInboundOptions)
	if tun.AutoRoute || tun.StrictRoute || tun.MTU != AndroidTunMTU || tun.InterfaceName != "" || len(tun.Address) != 2 ||
		tun.Address[0].String() != AndroidTunAddress {
		t.Fatalf("tun not adjusted: %+v", tun)
	}
	if o.Route.DefaultInterface != "" {
		t.Fatal("default_interface kept")
	}
	if len(o.Route.Rules) != 2 || o.Route.Rules[0].DefaultOptions.Action != C.RuleActionTypeSniff ||
		o.Route.Rules[1].DefaultOptions.Action != C.RuleActionTypeHijackDNS {
		t.Fatalf("sniff/hijack-dns not added: %+v", o.Route.Rules)
	}
	// Idempotent: a second pass adds nothing.
	useAndroidTun(&o, Options{TunFD: 3, Tuning: &Tuning{MTU: 1400}})
	if len(o.Route.Rules) != 2 || o.Inbounds[0].Options.(*option.TunInboundOptions).MTU != 1400 {
		t.Fatalf("second pass: %d rules", len(o.Route.Rules))
	}

	// A profile without a TUN inbound gets one.
	o2 := option.Options{}
	useAndroidTun(&o2, Options{TunFD: 3})
	if len(o2.Inbounds) != 1 || o2.Inbounds[0].Type != C.TypeTun {
		t.Fatalf("no tun added: %+v", o2.Inbounds)
	}
}

func TestTunFDNeedsAndroid(t *testing.T) {
	m := &singBox{}
	err := m.Start([]byte(`{"outbounds":[{"type":"direct","tag":"d"}]}`), Options{TunFD: 3})
	if err == nil {
		_ = m.Stop()
		t.Fatal("TunFD accepted on desktop")
	}
}
