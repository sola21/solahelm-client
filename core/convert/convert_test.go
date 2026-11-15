package convert

import (
	"encoding/base64"
	"fmt"
	"net/url"
	"strings"
	"testing"

	"github.com/metacubex/mihomo/adapter"
	"go.yaml.in/yaml/v3"
)

const links = "hysteria2://pass@vps1.example.org:443,20000-30000?sni=vps1.example.org#DE-hy2\n" +
	"naive+https://u:p@vps1.example.org:6443#DE-naive\n" +
	"anytls://pass@vps1.example.org:9443?sni=vps1.example.org#DE-anytls\n" +
	"vless://11111111-2222-3333-4444-555555555555@vps2.example.org:8443?security=reality&type=tcp&sni=www.microsoft.com&pbk=Z3FxbHlYb2dKcVhuYlpsSFZqU3pCQ3pzWm1yRk1aTnQ&sid=a1b2&fp=chrome#FL-vless\n" +
	"trojan://pass@vps1.example.org:7443?sni=vps1.example.org#DE-trojan\n" +
	"tuic://11111111-2222-3333-4444-555555555555:pass@vps1.example.org:8444?sni=vps1.example.org&congestion_control=bbr#DE-tuic\n"

func TestLinksToMihomo(t *testing.T) {
	for name, body := range map[string]string{
		"plain":  links,
		"base64": base64.StdEncoding.EncodeToString([]byte(links)),
	} {
		t.Run(name, func(t *testing.T) {
			r, err := LinksToMihomo([]byte(body), "")
			if err != nil {
				t.Fatal(err)
			}
			if r.Proxies != 6 {
				t.Fatalf("proxies = %d, want 6", r.Proxies)
			}
			if len(r.Skipped) != 0 {
				t.Fatalf("skipped = %v", r.Skipped)
			}
			var cfg map[string]any
			if err := yaml.Unmarshal(r.YAML, &cfg); err != nil {
				t.Fatal(err)
			}
			for _, k := range []string{"proxies", "proxy-groups", "rules", "tun", "dns"} {
				if cfg[k] == nil {
					t.Fatalf("missing %q", k)
				}
			}
			ps := cfg["proxies"].([]any)
			hy := ps[0].(map[string]any)
			if hy["type"] != "hysteria2" || hy["ports"] != "443,20000-30000" {
				t.Fatalf("hysteria2 with port hopping: %v", hy)
			}
			// The naive link keeps its place in the list.
			nv := ps[1].(map[string]any)
			if nv["type"] != TypeNaive || nv["name"] != "DE-naive" || nv["server"] != "vps1.example.org" ||
				nv["port"] != 6443 || nv["username"] != "u" || nv["password"] != "p" {
				t.Fatalf("naive: %v", nv)
			}
			auto := cfg["proxy-groups"].([]any)[1].(map[string]any)
			if !strings.Contains(fmt.Sprint(auto["proxies"]), "DE-naive") {
				t.Fatalf("naive is not in the auto group: %v", auto)
			}
		})
	}
}

func TestNothingUsable(t *testing.T) {
	if _, err := LinksToMihomo([]byte("foo://u:p@x:1#a\n"), ""); err == nil {
		t.Fatal("expected an error")
	}
}

func TestNaiveLinks(t *testing.T) {
	r, err := LinksToMihomo([]byte("naive+quic://us%40er:p%3Ass@[2001:db8::1]:8443?sni=cdn.example.org"+
		"&extra-headers=X-A%3A%201%0D%0AX-B%3A%202&insecure-concurrency=2#Same\n"+
		"naive+https://u:p@vps1.example.org#Same\n"+
		"naive+https://broken:p@:1#x\n"), "")
	if err != nil {
		t.Fatal(err)
	}
	if r.Proxies != 2 || strings.Join(r.Skipped, ",") != "naive+https" {
		t.Fatalf("proxies %d, skipped %v", r.Proxies, r.Skipped)
	}
	var cfg map[string]any
	if err := yaml.Unmarshal(r.YAML, &cfg); err != nil {
		t.Fatal(err)
	}
	ps := cfg["proxies"].([]any)
	q := ps[0].(map[string]any)
	if q["quic"] != true || q["server"] != "2001:db8::1" || q["port"] != 8443 || q["username"] != "us@er" ||
		q["password"] != "p:ss" || q["sni"] != "cdn.example.org" || q["insecure-concurrency"] != 2 {
		t.Fatalf("naive+quic: %v", q)
	}
	if h := q["extra-headers"].(map[string]any); h["X-A"] != "1" || h["X-B"] != "2" {
		t.Fatalf("headers: %v", h)
	}
	h := ps[1].(map[string]any)
	if h["port"] != 443 || h["quic"] != nil || h["name"] != "Same 2" {
		t.Fatalf("naive+https, default port, unique name: %v", h)
	}
}

func TestRoutingTemplates(t *testing.T) {
	load := func(routing string) map[string]any {
		t.Helper()
		r, err := LinksToMihomo([]byte(links), routing)
		if err != nil {
			t.Fatal(err)
		}
		var cfg map[string]any
		if err := yaml.Unmarshal(r.YAML, &cfg); err != nil {
			t.Fatal(err)
		}
		return cfg
	}
	rules := func(cfg map[string]any) []string {
		var out []string
		for _, r := range cfg["rules"].([]any) {
			out = append(out, r.(string))
		}
		return out
	}

	all := load(RoutingAll)
	if all["rule-providers"] != nil {
		t.Fatal("the all-VPN template has no rule sets")
	}
	if r := rules(all); r[len(r)-1] != "MATCH,"+GroupProxy || len(r) != len(localRules)+1 {
		t.Fatalf("all: %v", r)
	}
	if strings.Join(rules(load("")), "|") != strings.Join(rules(all), "|") {
		t.Fatal(`"" must be the all-VPN template`)
	}

	ru := load(RoutingRuDirect)
	providers := ru["rule-providers"].(map[string]any)
	if len(providers) != len(ruDirectSets) {
		t.Fatalf("providers: %d", len(providers))
	}
	for name, p := range providers {
		pm := p.(map[string]any)
		if pm["proxy"] != GroupProxy || !strings.HasPrefix(pm["url"].(string), "https://github.com/") {
			t.Fatalf("%s: %v", name, pm)
		}
	}
	r := rules(ru)
	if r[0] != "RULE-SET,ru-inline-banned,"+GroupProxy || r[len(r)-1] != "MATCH,"+GroupProxy {
		t.Fatalf("ru-direct order: %v", r)
	}
	// Every RULE-SET points at a defined provider.
	for _, line := range r {
		if f := strings.Split(line, ","); f[0] == "RULE-SET" && providers[f[1]] == nil {
			t.Fatalf("undefined rule set in %q", line)
		}
	}
	if ru["dns"].(map[string]any)["direct-nameserver"] == nil {
		t.Fatal("ru-direct resolves direct traffic with a local resolver")
	}

	if _, err := LinksToMihomo([]byte(links), "bogus"); err == nil {
		t.Fatal("unknown template accepted")
	}
}

func TestShadowTLSPlugin(t *testing.T) {
	plugin := url.QueryEscape("shadow-tls;host=www.example.com;password=stls-pass;version=3")
	body := "ss://2022-blake3-aes-128-gcm:" + url.QueryEscape("AAAAAAAAAAAAAAAAAAAAAA==") + "@vps1.example.org:4443/?plugin=" + plugin + "#DE-stls\n" +
		"ss://2022-blake3-aes-128-gcm:" + url.QueryEscape("AAAAAAAAAAAAAAAAAAAAAA==:BBBBBBBBBBBBBBBBBBBBBB==") + "@vps1.example.org:2443#DE-ss\n"
	r, err := LinksToMihomo([]byte(body), "")
	if err != nil {
		t.Fatal(err)
	}
	var cfg map[string]any
	if err := yaml.Unmarshal(r.YAML, &cfg); err != nil {
		t.Fatal(err)
	}
	ps := cfg["proxies"].([]any)
	if len(ps) != 2 {
		t.Fatalf("proxies: %v", ps)
	}
	st, ss := ps[0].(map[string]any), ps[1].(map[string]any)
	opts, _ := st["plugin-opts"].(map[string]any)
	if st["plugin"] != "shadow-tls" || opts["host"] != "www.example.com" || opts["password"] != "stls-pass" ||
		opts["version"] != 3 || st["client-fingerprint"] != "chrome" {
		t.Fatalf("ShadowTLS lost: %v", st)
	}
	if ss["plugin"] != nil {
		t.Fatalf("plain Shadowsocks got a plugin: %v", ss)
	}
	// mihomo accepts the node as it is.
	for _, p := range ps {
		if _, err := adapter.ParseProxy(p.(map[string]any)); err != nil {
			t.Fatalf("mihomo: %v (%v)", err, p)
		}
	}
}
