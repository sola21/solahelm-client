package engine

import (
	"context"
	"errors"
	"net/netip"
	"os"

	box "github.com/sagernet/sing-box"
	C "github.com/sagernet/sing-box/constant"
	"github.com/sagernet/sing-box/experimental/deprecated"
	"github.com/sagernet/sing-box/include"
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
	ctx = include.Context(service.ContextWith(ctx, deprecated.NewStderrManager(log.StdLogger())))

	parsed, err := json.UnmarshalExtendedContext[option.Options](ctx, config)
	if err != nil {
		return err
	}
	if err := opts.Tuning.validate(); err != nil {
		return err
	}
	adjustSingBoxInbounds(&parsed, opts)
	applySingBoxTuning(&parsed, opts.Tuning)
	if err := injectSingBoxRules(&parsed, opts.Rules); err != nil {
		return err
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
		return err
	}
	if err := instance.Start(); err != nil {
		_ = instance.Close()
		cancel()
		return err
	}
	s.instance, s.cancel = instance, cancel
	return nil
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
