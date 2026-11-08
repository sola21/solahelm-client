package detect

import (
	"encoding/base64"
	"testing"

	"github.com/sola21/solahelm-client/core/engine"
)

func TestDetect(t *testing.T) {
	links := "hysteria2://pass@vps1.example.org:443?sni=vps1.example.org#hy2\n" +
		"vless://uuid@vps1.example.org:8443?security=reality&type=tcp#vless\n"

	cases := []struct {
		name   string
		in     string
		prefer engine.Kind
		format Format
		core   engine.Kind
		unsup  int
	}{
		{"sing-box json", `{"log":{},"outbounds":[{"type":"direct"}]}`, "", SingBoxJSON, engine.SingBox, 0},
		{"sing-box json with comments", "{\n // comment\n \"outbounds\": []\n}", "", SingBoxJSON, engine.SingBox, 0},
		{"clash yaml", "mixed-port: 7890\nproxies:\n  - {name: a, type: hysteria2, server: x, port: 1}\nrules:\n  - MATCH,DIRECT\n", "", ClashYAML, engine.Mihomo, 0},
		{"clash json", `{"proxies":[],"rules":["MATCH,DIRECT"]}`, "", ClashYAML, engine.Mihomo, 0},
		{"bom + yaml", "\xef\xbb\xbfproxy-groups: []\n", "", ClashYAML, engine.Mihomo, 0},
		{"plain links", links, "", ShareLinks, engine.Mihomo, 0},
		{"plain links, prefer sing-box", links, engine.SingBox, ShareLinks, engine.Mihomo, 0},
		{"base64 links", base64.StdEncoding.EncodeToString([]byte(links)), "", ShareLinks, engine.Mihomo, 0},
		{"naive is reported as unsupported", links + "naive+https://u:p@vps1.example.org:6443#n\n", "", ShareLinks, engine.Mihomo, 1},
		{"ssr runs on mihomo", links + "ssr://abc\n", "", ShareLinks, engine.Mihomo, 0},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			r, err := Detect([]byte(c.in), c.prefer)
			if err != nil {
				t.Fatal(err)
			}
			if r.Format != c.format || r.Core != c.core || len(r.Unsupported) != c.unsup {
				t.Fatalf("got format=%s core=%s unsupported=%v (%s)", r.Format, r.Core, r.Unsupported, r.Reason)
			}
		})
	}
}

func TestDetectUnknown(t *testing.T) {
	for _, in := range []string{"", "hello world", "<html><body>404</body></html>", `{"foo":1}`} {
		if _, err := Detect([]byte(in), ""); err == nil {
			t.Errorf("%q: expected error", in)
		}
	}
}
