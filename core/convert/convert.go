// Package convert turns a list of share links (hysteria2://, vless://, ...,
// plain or base64, e.g. a panel's "universal" subscription) into a complete
// mihomo config: proxies, a manual and an automatic group, DNS, TUN, rules.
//
// Link parsing is mihomo's own (common/convert), so whatever mihomo understands
// works here. Links mihomo can't run (naive+https://, masque://) are reported
// in Result.Skipped.
package convert

import (
	"errors"
	"fmt"
	"sort"
	"strings"

	mconv "github.com/metacubex/mihomo/common/convert"
	"go.yaml.in/yaml/v3"
)

// Group names in the generated config.
const (
	GroupProxy = "Proxy" // manual choice; the rules send traffic here
	GroupAuto  = "Auto"  // fastest by latency
)

// Result is a generated config.
type Result struct {
	YAML    []byte
	Proxies int
	Skipped []string // schemes of links that could not be converted
}

// ErrNoProxies means nothing usable was found.
var ErrNoProxies = errors.New("no supported links in the subscription")

// LinksToMihomo converts share links (plain or base64) to a mihomo YAML config.
func LinksToMihomo(body []byte) (*Result, error) {
	proxies, err := mconv.ConvertsV2Ray(body)
	if err != nil && len(proxies) == 0 {
		return nil, err
	}
	res := &Result{Skipped: skippedSchemes(body, len(proxies))}
	if len(proxies) == 0 {
		return nil, ErrNoProxies
	}
	names := make([]string, 0, len(proxies))
	for _, p := range proxies {
		names = append(names, fmt.Sprint(p["name"]))
	}
	res.Proxies = len(proxies)

	cfg := map[string]any{
		"mixed-port":        7890,
		"allow-lan":         false,
		"mode":              "rule",
		"log-level":         "info",
		"ipv6":              false,
		"unified-delay":     true,
		"tcp-concurrent":    true,
		"find-process-mode": "strict",
		"profile":           map[string]any{"store-selected": true},
		"tun": map[string]any{
			"enable":                true,
			"stack":                 "gvisor",
			"auto-route":            true,
			"auto-detect-interface": true,
			"strict-route":          true,
			"dns-hijack":            []string{"any:53"},
		},
		"dns": map[string]any{
			"enable":        true,
			"ipv6":          false,
			"enhanced-mode": "fake-ip",
			"fake-ip-range": "198.18.0.1/16",
			"fake-ip-filter": []string{
				"*.lan", "*.local", "+.msftconnecttest.com", "+.msftncsi.com", "time.windows.com",
			},
			// Plain resolvers to find the proxy servers themselves...
			"default-nameserver":      []string{"77.88.8.8", "1.1.1.1"},
			"proxy-server-nameserver": []string{"77.88.8.8", "1.1.1.1"},
			// ...and encrypted DNS through the tunnel for everything else.
			"nameserver": []string{
				"https://1.1.1.1/dns-query#" + GroupProxy,
				"https://8.8.8.8/dns-query#" + GroupProxy,
			},
		},
		"proxies": proxies,
		"proxy-groups": []map[string]any{
			{"name": GroupProxy, "type": "select", "proxies": append([]string{GroupAuto}, append(names, "DIRECT")...)},
			{
				"name": GroupAuto, "type": "url-test", "proxies": names,
				"url": "https://www.gstatic.com/generate_204", "interval": 300, "tolerance": 50,
			},
		},
		"rules": []string{
			"IP-CIDR,127.0.0.0/8,DIRECT,no-resolve",
			"IP-CIDR,10.0.0.0/8,DIRECT,no-resolve",
			"IP-CIDR,172.16.0.0/12,DIRECT,no-resolve",
			"IP-CIDR,192.168.0.0/16,DIRECT,no-resolve",
			"IP-CIDR,169.254.0.0/16,DIRECT,no-resolve",
			"IP-CIDR,224.0.0.0/4,DIRECT,no-resolve",
			"DOMAIN-SUFFIX,local,DIRECT",
			"DOMAIN-SUFFIX,lan,DIRECT",
			"MATCH," + GroupProxy,
		},
	}
	// yaml.v3 sorts map keys; that's fine for mihomo.
	out, err := yaml.Marshal(cfg)
	if err != nil {
		return nil, err
	}
	res.YAML = out
	return res, nil
}

// skippedSchemes lists schemes of links that produced no proxy. It's only a
// hint for the UI, so it simply compares counts per scheme.
func skippedSchemes(body []byte, converted int) []string {
	text := string(mconv.DecodeBase64(body))
	total := map[string]int{}
	lines := 0
	for _, line := range strings.Split(text, "\n") {
		scheme, _, ok := strings.Cut(strings.TrimSpace(line), "://")
		if !ok {
			continue
		}
		total[strings.ToLower(scheme)]++
		lines++
	}
	if lines == converted {
		return nil
	}
	known := map[string]bool{
		"hysteria": true, "hysteria2": true, "hy2": true, "tuic": true, "trojan": true, "vless": true,
		"vmess": true, "ss": true, "ssr": true, "socks": true, "socks5": true, "socks5h": true,
		"http": true, "https": true, "anytls": true, "mierus": true,
	}
	var out []string
	for s := range total {
		if !known[s] {
			out = append(out, s)
		}
	}
	sort.Strings(out)
	return out
}
