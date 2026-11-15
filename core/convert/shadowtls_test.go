package convert

import (
	"testing"

	"go.yaml.in/yaml/v3"
)

// The link the SolaHelm panel writes for ShadowTLS v3.
const shadowTLSLinks = "hysteria2://pass@vps1.example.org:443?sni=vps1.example.org#DE-hy2\n" +
	"ss://2022-blake3-aes-128-gcm:AAAAAAAAAAAAAAAAAAAAAA%3D%3D@vps1.example.org:4443/" +
	"?plugin=shadow-tls%3Bhost%3Dwww.lg.com%3Bpassword%3D5f2a80c50fc001b6ca71f3e7%3Bversion%3D3#DE-stls\n" +
	"ss://2022-blake3-aes-128-gcm:AAAAAAAAAAAAAAAAAAAAAA%3D%3D@vps1.example.org:2443#DE-ss\n"

func TestShadowTLSKeepsPlugin(t *testing.T) {
	r, err := LinksToMihomo([]byte(shadowTLSLinks), "")
	if err != nil {
		t.Fatal(err)
	}
	var cfg struct {
		Proxies []map[string]any `yaml:"proxies"`
	}
	if err := yaml.Unmarshal(r.YAML, &cfg); err != nil {
		t.Fatal(err)
	}
	var stls, plain map[string]any
	for _, p := range cfg.Proxies {
		switch p["name"] {
		case "DE-stls":
			stls = p
		case "DE-ss":
			plain = p
		}
	}
	if stls == nil || plain == nil {
		t.Fatalf("proxies missing: %v", cfg.Proxies)
	}
	if stls["plugin"] != "shadow-tls" {
		t.Fatalf("plugin = %v, want shadow-tls (proxy: %v)", stls["plugin"], stls)
	}
	opts, _ := stls["plugin-opts"].(map[string]any)
	if opts["host"] != "www.lg.com" || opts["password"] != "5f2a80c50fc001b6ca71f3e7" || opts["version"] != 3 {
		t.Fatalf("plugin-opts = %v", opts)
	}
	if plain["plugin"] != nil {
		t.Fatalf("plain ss link must stay without a plugin: %v", plain)
	}
}

func TestParseShadowTLSIgnoresOtherLinks(t *testing.T) {
	for _, l := range []string{
		"ss://2022-blake3-aes-128-gcm:AAAAAAAAAAAAAAAAAAAAAA%3D%3D@h.example.org:2443#x",
		"ss://m:p@h.example.org:2443/?plugin=obfs-local%3Bobfs%3Dhttp#x",
		"hysteria2://p@h.example.org:443#x",
	} {
		if parseSSPlugin(l) != nil {
			t.Fatalf("%q must not be read as ShadowTLS", l)
		}
	}
}
