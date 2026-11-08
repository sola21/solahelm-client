//go:build android && cmfa

package mobile

import (
	"net"
	"strings"

	mihomoDNS "github.com/metacubex/mihomo/dns"

	"github.com/sola21/solahelm-client/core/engine"
)

// SetSystemDNS tells mihomo which resolvers "system" means: a comma-separated
// list of IPs of the underlying (non-VPN) network. With the cmfa tag mihomo
// can't read them itself; sing-box's "local" DNS server uses them too.
func SetSystemDNS(servers string) {
	var ips, addrs []string
	for _, s := range strings.Split(servers, ",") {
		s = strings.TrimSpace(s)
		if s == "" {
			continue
		}
		ips = append(ips, s)
		addrs = append(addrs, net.JoinHostPort(s, "53"))
	}
	engine.SetSystemDNSServers(ips)
	mihomoDNS.UpdateSystemDNS(addrs)
}
