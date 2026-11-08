package engine

import (
	"context"
	"errors"
	"net/netip"
	"os"

	box "github.com/sagernet/sing-box"
	"github.com/sagernet/sing-box/adapter"
	C "github.com/sagernet/sing-box/constant"
	"github.com/sagernet/sing-box/experimental/deprecated"
	"github.com/sagernet/sing-box/log"
	"github.com/sagernet/sing-box/option"
	"github.com/sagernet/sing/common/json"
	"github.com/sagernet/sing/common/json/badoption"
	"github.com/sagernet/sing/service"
	"github.com/sagernet/sing/service/filemanager"
)

type singBox struct {
	instance *box.Box
	cancel   context.CancelFunc
}

func (s *singBox) Kind() Kind { return SingBox }

func (s *singBox) Start(config []byte, opts Options) error {
	ctx := context.Background()
	if opts.WorkDir != "" {
		if err := os.MkdirAll(opts.WorkDir, 0o755); err != nil {
			return err
		}
		ctx = filemanager.WithDefault(ctx, opts.WorkDir, os.TempDir(), os.Getuid(), os.Getgid())
	}
	ctx = singBoxContext(service.ContextWith(ctx, deprecated.NewStderrManager(log.StdLogger())))

	parsed, err := json.UnmarshalExtendedContext[option.Options](ctx, config)
	if err != nil {
		return err
	}
	if err := opts.Tuning.validate(); err != nil {
		return err
	}
	var platform singBoxPlatform
	if opts.TunFD > 0 {
		platform = newSingBoxPlatform(opts.TunFD)
		if platform == nil {
			return errNoPlatform
		}
		ctx = service.ContextWith[adapter.PlatformInterface](ctx, platform)
		useAndroidTun(&parsed, opts)
	}
	fail := func(err error) error {
		if platform != nil {
			platform.closeUnused()
		}
		return err
	}
	adjustSingBoxInbounds(&parsed, opts)
	applySingBoxTuning(&parsed, opts.Tuning)
	if err := injectSingBoxRules(&parsed, opts.Rules); err != nil {
		return fail(err)
	}
	if opts.FindProcess {
		if parsed.Route == nil {
			parsed.Route = &option.RouteOptions{}
		}
		parsed.Route.FindProcess = true
	}
	if opts.Controller != "" {
		if parsed.Experimental == nil {
			parsed.Experimental = &option.ExperimentalOptions{}
		}
		if parsed.Experimental.ClashAPI == nil {
			parsed.Experimental.ClashAPI = &option.ClashAPIOptions{}
		}
		parsed.Experimental.ClashAPI.ExternalController = opts.Controller
		parsed.Experimental.ClashAPI.Secret = opts.Secret
	}

	ctx, cancel := context.WithCancel(service.ExtendContext(ctx))
	instance, err := box.New(box.Options{Context: ctx, Options: parsed})
	if err != nil {
		cancel()
		return fail(err)
	}
	if err := instance.Start(); err != nil {
		_ = instance.Close()
		cancel()
		return fail(err)
	}
	s.instance, s.cancel = instance, cancel
	return nil
}

var errNoPlatform = errors.New("a TUN file descriptor is only supported on Android")

// singBoxPlatform is sing-box's platform interface for an OS-opened TUN (Android).
type singBoxPlatform interface {
	adapter.PlatformInterface
	closeUnused()
}

// useAndroidTun makes the profile's TUN inbound use the interface Android's
// VpnService opened (adding one if the profile has none): fixed addresses and
// MTU that match the VpnService, no routing of its own (Android routes), and
// DNS sent to the TUN's DNS address answered by sing-box.
func useAndroidTun(o *option.Options, opts Options) {
	mtu := AndroidTunMTU
	if opts.Tuning != nil && opts.Tuning.MTU != 0 {
		mtu = opts.Tuning.MTU
	}
	addrs := badoption.Listable[netip.Prefix]{netip.MustParsePrefix(AndroidTunAddress), netip.MustParsePrefix(AndroidTunAddress6)}
	found := false
	kept := o.Inbounds[:0]
	for _, in := range o.Inbounds {
		t, ok := in.Options.(*option.TunInboundOptions)
		if ok && found {
			continue // one VPN interface only
		}
		if ok {
			found = true
			t.Address = addrs
			t.MTU = mtu
			t.AutoRoute = false
			t.StrictRoute = false
			t.AutoRedirect = false
			t.InterfaceName = ""
			t.IncludePackage, t.ExcludePackage = nil, nil
			t.IncludeUID, t.ExcludeUID, t.IncludeUIDRange, t.ExcludeUIDRange = nil, nil, nil, nil
			t.IncludeAndroidUser = nil
			t.RouteAddress, t.RouteExcludeAddress = nil, nil
			t.RouteAddressSet, t.RouteExcludeAddressSet = nil, nil
		}
		kept = append(kept, in)
	}
	o.Inbounds = kept
	if !found {
		o.Inbounds = append(o.Inbounds, option.Inbound{
			Type:    C.TypeTun,
			Tag:     "solahelm-tun",
			Options: &option.TunInboundOptions{Address: addrs, MTU: mtu, Stack: "gvisor"},
		})
	}
	if o.Route == nil {
		o.Route = &option.RouteOptions{}
	}
	// A default interface name from a desktop profile would break dialing here.
	o.Route.DefaultInterface = ""
	// With a platform interface sing-box discards its log unless an output is
	// set; stderr ends up in logcat (the app's log view reads the Clash API).
	if o.Log == nil {
		o.Log = &option.LogOptions{}
	}
	if o.Log.Output == "" {
		o.Log.Output = "stderr"
	}
	ensureSniffAndDNSHijack(o.Route)
}

// ensureSniffAndDNSHijack puts "sniff" and "hijack-dns for DNS" at the top of
// the route rules when the profile doesn't have them: Android sends all DNS to
// the TUN's DNS address, which only sing-box's DNS can answer.
func ensureSniffAndDNSHijack(r *option.RouteOptions) {
	hasSniff, hasHijack := false, false
	for _, rule := range r.Rules {
		var a string
		if rule.Type == C.RuleTypeLogical {
			a = rule.LogicalOptions.Action
		} else {
			a = rule.DefaultOptions.Action
		}
		hasSniff = hasSniff || a == C.RuleActionTypeSniff
		hasHijack = hasHijack || a == C.RuleActionTypeHijackDNS
	}
	var head []option.Rule
	if !hasSniff {
		head = append(head, option.Rule{
			Type:           C.RuleTypeDefault,
			DefaultOptions: option.DefaultRule{RuleAction: option.RuleAction{Action: C.RuleActionTypeSniff}},
		})
	}
	if !hasHijack {
		head = append(head, option.Rule{
			Type: C.RuleTypeDefault,
			DefaultOptions: option.DefaultRule{
				RawDefaultRule: option.RawDefaultRule{Protocol: badoption.Listable[string]{C.ProtocolDNS}},
				RuleAction:     option.RuleAction{Action: C.RuleActionTypeHijackDNS},
			},
		})
	}
	if len(head) > 0 {
		r.Rules = append(head, r.Rules...)
	}
}

func adjustSingBoxInbounds(o *option.Options, opts Options) {
	if !opts.ProxyOnly && !opts.LoopbackOnly && opts.MixedPort == 0 && opts.TUNStack == "" {
		return
	}
	loopback := badoption.Addr(netip.AddrFrom4([4]byte{127, 0, 0, 1}))
	kept := o.Inbounds[:0]
	mixedSet := false
	for _, in := range o.Inbounds {
		if opts.ProxyOnly && (in.Type == C.TypeTun || in.Type == C.TypeRedirect || in.Type == C.TypeTProxy) {
			continue
		}
		if w, ok := in.Options.(option.ListenOptionsWrapper); ok && (opts.ProxyOnly || opts.LoopbackOnly) {
			l := w.TakeListenOptions()
			l.Listen = &loopback
			w.ReplaceListenOptions(l)
		}
		if t, ok := in.Options.(*option.TunInboundOptions); ok && opts.TUNStack != "" {
			t.Stack = opts.TUNStack
		}
		if m, ok := in.Options.(*option.HTTPMixedInboundOptions); ok {
			if opts.ProxyOnly {
				m.SetSystemProxy = false
			}
			if in.Type == C.TypeMixed && opts.MixedPort != 0 && !mixedSet {
				m.ListenPort = uint16(opts.MixedPort)
				mixedSet = true
			}
		}
		kept = append(kept, in)
	}
	if opts.MixedPort != 0 && !mixedSet {
		kept = append(kept, option.Inbound{
			Type: C.TypeMixed,
			Tag:  "solahelm-mixed",
			Options: &option.HTTPMixedInboundOptions{
				ListenOptions: option.ListenOptions{Listen: &loopback, ListenPort: uint16(opts.MixedPort)},
			},
		})
	}
	o.Inbounds = kept
}

func (s *singBox) Stop() error {
	if s.instance == nil {
		return nil
	}
	err := s.instance.Close()
	s.cancel()
	s.instance, s.cancel = nil, nil
	if errors.Is(err, context.Canceled) {
		err = nil
	}
	return err
}
