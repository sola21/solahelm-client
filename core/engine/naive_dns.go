package engine

import (
	"context"
	"errors"
	"net"
	"net/netip"
	"strings"

	mdialer "github.com/metacubex/mihomo/component/dialer"
	"github.com/metacubex/mihomo/component/resolver"
	box "github.com/sagernet/sing-box"
	"github.com/sagernet/sing-box/adapter"
	"github.com/sagernet/sing-box/adapter/outbound"
	"github.com/sagernet/sing-box/dns"
	"github.com/sagernet/sing-box/include"
	"github.com/sagernet/sing-box/log"
	"github.com/sagernet/sing-box/option"
	M "github.com/sagernet/sing/common/metadata"
	N "github.com/sagernet/sing/common/network"

	mDNS "github.com/miekg/dns"
)

// The naive bridge leaves the way mihomo's own proxies do:
//   - connections go through mihomo's dialer, so they are bound to the real
//     interface while mihomo's TUN is up (protected on Android) and never loop
//     back into the tunnel;
//   - the servers' names are resolved by mihomo's resolver for proxy servers
//     (proxy-server-nameserver, else the main DNS, else the system), so the
//     user's DNS settings apply.

const (
	outboundTypeMihomo = "solahelm-mihomo-direct"
	dnsTypeMihomo      = "solahelm-mihomo"
)

// bridgeContext registers sing-box's protocols plus the two above.
func bridgeContext(ctx context.Context) context.Context {
	outbounds := include.OutboundRegistry()
	outbound.Register[option.StubOptions](outbounds, outboundTypeMihomo,
		func(ctx context.Context, router adapter.Router, logger log.ContextLogger, tag string, _ option.StubOptions) (adapter.Outbound, error) {
			return &mihomoDirect{Adapter: outbound.NewAdapter(outboundTypeMihomo, tag, []string{N.NetworkTCP, N.NetworkUDP}, nil)}, nil
		})
	dnsTransports := include.DNSTransportRegistry()
	dns.RegisterTransport[option.LocalDNSServerOptions](dnsTransports, dnsTypeMihomo,
		func(ctx context.Context, logger log.ContextLogger, tag string, _ option.LocalDNSServerOptions) (adapter.DNSTransport, error) {
			return &mihomoDNS{TransportAdapter: dns.NewTransportAdapter(dnsTypeMihomo, tag, nil)}, nil
		})
	return box.Context(ctx, include.InboundRegistry(), outbounds, include.EndpointRegistry(),
		dnsTransports, include.ServiceRegistry(), include.CertificateProviderRegistry())
}

// mihomoDirect dials with mihomo's dialer.
type mihomoDirect struct {
	outbound.Adapter
}

func (d *mihomoDirect) DialContext(ctx context.Context, network string, destination M.Socksaddr) (net.Conn, error) {
	// naive asks for connected UDP sockets here too (QUIC).
	n := "tcp"
	if N.NetworkName(network) == N.NetworkUDP {
		n = "udp"
	}
	return mdialer.DialContext(ctx, n, destination.String(), mdialer.WithResolver(resolver.ProxyServerHostResolver))
}

func (d *mihomoDirect) ListenPacket(ctx context.Context, destination M.Socksaddr) (net.PacketConn, error) {
	addr := destination.Addr
	if destination.IsFqdn() {
		ip, err := resolver.ResolveIPWithResolver(ctx, destination.Fqdn, resolver.ProxyServerHostResolver)
		if err != nil {
			return nil, err
		}
		addr = ip
	}
	network := "udp4"
	if addr.Unmap().Is6() {
		network = "udp6"
	}
	return mdialer.ListenPacket(ctx, network, "", netip.AddrPortFrom(addr.Unmap(), destination.Port))
}

var _ adapter.Outbound = (*mihomoDirect)(nil)

// mihomoDNS answers with mihomo's resolver for proxy servers.
type mihomoDNS struct {
	dns.TransportAdapter
}

func (t *mihomoDNS) Start(adapter.StartStage, *adapter.Scope) error { return nil }
func (t *mihomoDNS) Close() error                                   { return nil }
func (t *mihomoDNS) Reset()                                         {}

func (t *mihomoDNS) ExchangeAsync(ctx context.Context, m *mDNS.Msg, callback func(*mDNS.Msg, error)) {
	go func() { callback(t.Exchange(ctx, m)) }()
}

// Exchange answers A and AAAA questions; anything else gets an empty answer.
func (t *mihomoDNS) Exchange(ctx context.Context, m *mDNS.Msg) (*mDNS.Msg, error) {
	r := new(mDNS.Msg)
	r.SetReply(m)
	if len(m.Question) != 1 {
		return r, nil
	}
	q := m.Question[0]
	host := strings.TrimSuffix(q.Name, ".")
	var (
		ips []netip.Addr
		err error
	)
	switch q.Qtype {
	case mDNS.TypeA:
		ips, err = resolver.LookupIPv4WithResolver(ctx, host, resolver.ProxyServerHostResolver)
	case mDNS.TypeAAAA:
		ips, err = resolver.LookupIPv6WithResolver(ctx, host, resolver.ProxyServerHostResolver)
	default:
		return r, nil
	}
	if err != nil {
		// IPv6 off in the profile, no such record...: an empty answer, so
		// naive goes on with the other address family.
		if errors.Is(err, resolver.ErrIPv6Disabled) || errors.Is(err, resolver.ErrIPVersion) ||
			errors.Is(err, resolver.ErrIPNotFound) {
			return r, nil
		}
		return nil, err
	}
	for _, ip := range ips {
		ip = ip.Unmap()
		hdr := mDNS.RR_Header{Name: q.Name, Rrtype: q.Qtype, Class: mDNS.ClassINET, Ttl: 60}
		switch {
		case ip.Is4() && q.Qtype == mDNS.TypeA:
			r.Answer = append(r.Answer, &mDNS.A{Hdr: hdr, A: ip.AsSlice()})
		case ip.Is6() && q.Qtype == mDNS.TypeAAAA:
			r.Answer = append(r.Answer, &mDNS.AAAA{Hdr: hdr, AAAA: ip.AsSlice()})
		}
	}
	return r, nil
}
