package engine

import (
	"encoding/json"
	"strings"
	"testing"

	"go.yaml.in/yaml/v3"
)

const naiveProfile = `mixed-port: 7890
proxies:
  - {name: hy, type: hysteria2, server: vps1.example.org, port: 443, password: x}
  - {name: DE naive, type: naive, server: vps1.example.org, port: 6443, username: u, password: p, quic: true, sni: cdn.example.org}
proxy-groups:
  - {name: Proxy, type: select, proxies: [hy, DE naive]}
rules:
  - MATCH,Proxy
`

func TestRewriteNaive(t *testing.T) {
	out, b, err := rewriteNaive([]byte(naiveProfile), true)
	if err != nil {
		t.Fatal(err)
	}
	if b == nil || strings.Join(b.Names(), ",") != "DE naive" {
		t.Fatalf("bridge: %+v", b)
	}
	var cfg map[string]any
	if err := yaml.Unmarshal(out, &cfg); err != nil {
		t.Fatal(err)
	}
	p := cfg["proxies"].([]any)[1].(map[string]any)
	if p["type"] != "socks5" || p["server"] != "127.0.0.1" || p["port"] != b.bridgePort || p["username"] != "n0" ||
		p["password"] != b.secret || p["name"] != "DE naive" || b.bridgePort <= 1 || len(b.secret) < 16 {
		t.Fatalf("socks5 in place of naive: %v", p)
	}
	if cfg["proxies"].([]any)[0].(map[string]any)["type"] != "hysteria2" {
		t.Fatal("other proxies must stay")
	}

	// The sing-box side: the inbound user n0 goes to the naive outbound n0,
	// which dials and resolves through mihomo.
	raw, err := b.singBoxConfig()
	if err != nil {
		t.Fatal(err)
	}
	var sb struct {
		Inbounds  []map[string]any `json:"inbounds"`
		Outbounds []map[string]any `json:"outbounds"`
		DNS       struct {
			Servers []map[string]any `json:"servers"`
		} `json:"dns"`
		Route struct {
			Rules []map[string]any `json:"rules"`
		} `json:"route"`
	}
	if err := json.Unmarshal(raw, &sb); err != nil {
		t.Fatal(err)
	}
	n := sb.Outbounds[0]
	if n["type"] != "naive" || n["server"] != "vps1.example.org" || n["server_port"] != float64(6443) ||
		n["quic"] != true || n["detour"] != "out" || n["tls"].(map[string]any)["server_name"] != "cdn.example.org" {
		t.Fatalf("naive outbound: %v", n)
	}
	if sb.Outbounds[1]["type"] != outboundTypeMihomo || sb.DNS.Servers[0]["type"] != dnsTypeMihomo {
		t.Fatalf("dialer / DNS: %v %v", sb.Outbounds[1], sb.DNS.Servers)
	}
	if sb.Inbounds[0]["listen_port"] != float64(b.bridgePort) || sb.Route.Rules[0]["outbound"] != "n0" {
		t.Fatalf("inbound / route: %v %v", sb.Inbounds, sb.Route.Rules)
	}
}

func TestRewriteNaiveNothingToDo(t *testing.T) {
	in := []byte("proxies:\n  - {name: naive-looking name, type: trojan, server: x, port: 1, password: p}\n")
	out, b, err := rewriteNaive(in, true)
	if err != nil || b != nil || string(out) != string(in) {
		t.Fatalf("out=%q b=%v err=%v", out, b, err)
	}
	if _, _, err := rewriteNaive([]byte("proxies:\n  - {name: n, type: naive, port: 1}\n"), false); err == nil {
		t.Fatal("a naive proxy without a server must be refused")
	}
}

// mihomo itself doesn't know "naive": the check goes through the same rewrite.
func TestValidateMihomoWithNaive(t *testing.T) {
	if err := Validate(Mihomo, []byte(naiveProfile)); err != nil {
		t.Fatal(err)
	}
}
