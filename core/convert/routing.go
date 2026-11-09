package convert

import (
	"fmt"
	"strings"
)

// Routing templates for configs made from links (a list of links carries no
// rules of its own). They follow the SolaHelm panel's presets.
const (
	RoutingAll      = "all"       // everything through the VPN, local networks direct
	RoutingRuDirect = "ru-direct" // Russian sites and apps direct, the rest through the VPN
)

// Routings lists the templates in the order the app shows them.
var Routings = []string{RoutingAll, RoutingRuDirect}

// Local networks: direct in every template.
var localRules = []string{
	"IP-CIDR,127.0.0.0/8,DIRECT,no-resolve",
	"IP-CIDR,10.0.0.0/8,DIRECT,no-resolve",
	"IP-CIDR,172.16.0.0/12,DIRECT,no-resolve",
	"IP-CIDR,192.168.0.0/16,DIRECT,no-resolve",
	"IP-CIDR,169.254.0.0/16,DIRECT,no-resolve",
	"IP-CIDR,224.0.0.0/4,DIRECT,no-resolve",
	"DOMAIN-SUFFIX,local,DIRECT",
	"DOMAIN-SUFFIX,lan,DIRECT",
}

type ruleSet struct {
	name, behavior, format, url string
}

const (
	legiz = "https://github.com/legiz-ru/mihomo-rule-sets/raw/main/"
	meta  = "https://github.com/MetaCubeX/meta-rules-dat/raw/meta/geo/"
)

// The panel's "Russia direct" preset: public rule sets by legiz-ru and MetaCubeX.
var ruDirectSets = []ruleSet{
	{"ru-inline-banned", "classical", "yaml", legiz + "other/inline/ru-inline-banned.yaml"},
	{"ru-inline", "classical", "yaml", legiz + "other/inline/ru-inline.yaml"},
	{"ru-app-list", "classical", "yaml", legiz + "other/ru-app-list.yaml"},
	{"torrent-trackers", "domain", "mrs", legiz + "other/torrent-trackers.mrs"},
	{"torrent-clients", "classical", "yaml", legiz + "other/torrent-clients.yaml"},
	{"geosite-ru", "domain", "mrs", meta + "geosite/category-ru.mrs"},
	{"xiaomi", "domain", "mrs", meta + "geosite/xiaomi.mrs"},
	{"blender", "domain", "mrs", meta + "geosite/blender.mrs"},
	{"drweb", "domain", "mrs", meta + "geosite/drweb.mrs"},
	{"debian", "domain", "mrs", meta + "geosite/debian.mrs"},
	{"canonical", "domain", "mrs", meta + "geosite/canonical.mrs"},
	{"python", "domain", "mrs", meta + "geosite/python.mrs"},
	{"geoip-ru", "ipcidr", "mrs", meta + "geoip/ru.mrs"},
}

func ruDirectRules() []string {
	p := GroupProxy
	return append(append([]string{
		"RULE-SET,ru-inline-banned," + p, // blocked in Russia: always through the VPN
		"PROCESS-NAME,Discord.exe," + p,
		"PROCESS-NAME,discord," + p,
	}, localRules...),
		"RULE-SET,ru-app-list,DIRECT",
		"RULE-SET,torrent-clients,DIRECT",
		"RULE-SET,torrent-trackers,DIRECT",
		"RULE-SET,ru-inline,DIRECT",
		"RULE-SET,geosite-ru,DIRECT",
		"RULE-SET,xiaomi,DIRECT",
		"RULE-SET,blender,DIRECT",
		"RULE-SET,drweb,DIRECT",
		"RULE-SET,debian,DIRECT",
		"RULE-SET,canonical,DIRECT",
		"RULE-SET,python,DIRECT",
		"RULE-SET,geoip-ru,DIRECT",
		"MATCH,"+p,
	)
}

// applyRouting puts the template's rules (and rule sets, DNS for direct
// traffic) into cfg.
func applyRouting(cfg map[string]any, routing string) error {
	switch routing {
	case "", RoutingAll:
		cfg["rules"] = append(append([]string{}, localRules...), "MATCH,"+GroupProxy)
	case RoutingRuDirect:
		providers := map[string]any{}
		for _, s := range ruDirectSets {
			ext := s.format
			providers[s.name] = map[string]any{
				"type":     "http",
				"behavior": s.behavior,
				"format":   s.format,
				"url":      s.url,
				"path":     "./rule-sets/" + s.name + "." + ext,
				"interval": 86400,
				// github.com is blocked on some networks: download through the VPN.
				// The files are cached, so later starts don't depend on it.
				"proxy": GroupProxy,
			}
		}
		cfg["rule-providers"] = providers
		cfg["rules"] = ruDirectRules()
		// Russian sites resolve with a Russian resolver, so they get local CDN addresses.
		if dns, ok := cfg["dns"].(map[string]any); ok {
			dns["direct-nameserver"] = []string{"77.88.8.8", "1.1.1.1"}
		}
	default:
		return fmt.Errorf("unknown routing template %q (want %s)", routing, strings.Join(Routings, ", "))
	}
	return nil
}
