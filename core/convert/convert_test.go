package convert

import (
	"encoding/base64"
	"strings"
	"testing"

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
			if r.Proxies != 5 {
				t.Fatalf("proxies = %d, want 5", r.Proxies)
			}
			if strings.Join(r.Skipped, ",") != "naive+https" {
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
		})
	}
}

func TestNothingUsable(t *testing.T) {
	if _, err := LinksToMihomo([]byte("naive+https://u:p@x:1#a\n"), ""); err == nil {
		t.Fatal("expected an error")
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
