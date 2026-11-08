//go:build android

package engine

import (
	"context"
	"errors"
	"net"
	"time"

	box "github.com/sagernet/sing-box"
	"github.com/sagernet/sing-box/adapter"
	C "github.com/sagernet/sing-box/constant"
	"github.com/sagernet/sing-box/dns"
	"github.com/sagernet/sing-box/include"
	"github.com/sagernet/sing-box/log"
	"github.com/sagernet/sing-box/option"

	mDNS "github.com/miekg/dns"
)

// singBoxContext registers sing-box's protocols, with "local" DNS replaced:
// stock "local" reads /etc/resolv.conf, which Android doesn't have, and ends up
// asking 127.0.0.1:53. Here it asks the real network's DNS servers that the
// app reports (SetSystemDNSServers). The app is excluded from its own VPN, so
// these queries never loop through the tunnel.
func singBoxContext(ctx context.Context) context.Context {
	registry := include.DNSTransportRegistry()
	dns.RegisterTransport[option.LocalDNSServerOptions](registry, C.DNSTypeLocal,
		func(ctx context.Context, logger log.ContextLogger, tag string, options option.LocalDNSServerOptions) (adapter.DNSTransport, error) {
			return &androidLocalDNS{TransportAdapter: dns.NewTransportAdapterWithLocalOptions(C.DNSTypeLocal, tag, options)}, nil
		})
	return box.Context(ctx, include.InboundRegistry(), include.OutboundRegistry(), include.EndpointRegistry(),
		registry, include.ServiceRegistry(), include.CertificateProviderRegistry())
}

// Used when Android hasn't reported any DNS servers yet.
var fallbackDNS = []string{"1.1.1.1", "8.8.8.8"}

type androidLocalDNS struct {
	dns.TransportAdapter
}

func (t *androidLocalDNS) Start(adapter.StartStage, *adapter.Scope) error { return nil }
func (t *androidLocalDNS) Close() error                                   { return nil }
func (t *androidLocalDNS) Reset()                                         {}

func (t *androidLocalDNS) ExchangeAsync(ctx context.Context, m *mDNS.Msg, callback func(*mDNS.Msg, error)) {
	go func() { callback(t.Exchange(ctx, m)) }()
}

func (t *androidLocalDNS) Exchange(ctx context.Context, m *mDNS.Msg) (*mDNS.Msg, error) {
	servers := systemDNSServers()
	if len(servers) == 0 {
		servers = fallbackDNS
	}
	var lastErr error
	for _, s := range servers {
		addr := net.JoinHostPort(s, "53")
		c := &mDNS.Client{Net: "udp", Timeout: 4 * time.Second}
		r, _, err := c.ExchangeContext(ctx, m, addr)
		if err == nil && r != nil && r.Truncated {
			c.Net = "tcp"
			r, _, err = c.ExchangeContext(ctx, m, addr)
		}
		if err == nil && r != nil {
			return r, nil
		}
		lastErr = err
		if ctx.Err() != nil {
			break
		}
	}
	if lastErr == nil {
		lastErr = errors.New("no DNS answer")
	}
	return nil, lastErr
}
