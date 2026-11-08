// Package detect figures out what a config or subscription body is and which
// core should run it.
package detect

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"sort"
	"strings"

	"go.yaml.in/yaml/v3"

	"github.com/sola21/solahelm-client/core/engine"
)

// Format is the shape of the input.
type Format string

const (
	SingBoxJSON Format = "sing-box-json" // full sing-box config
	ClashYAML   Format = "clash-yaml"    // full Clash Meta / mihomo config (YAML or JSON)
	ShareLinks  Format = "share-links"   // list of hysteria2:// vless:// ... links, plain or base64
)

// Result says what the input is and which core to use.
type Result struct {
	Format Format      `json:"format"`
	Core   engine.Kind `json:"core"`
	Reason string      `json:"reason"`
	// For ShareLinks only.
	Links       []string `json:"links,omitempty"`
	LinkCount   int      `json:"linkCount,omitempty"`   // len(Links); kept when Links is dropped from replies
	Protocols   []string `json:"protocols,omitempty"`   // distinct protocols found
	Unsupported []string `json:"unsupported,omitempty"` // protocols the chosen core cannot run
}

// ErrUnknown means the input is none of the supported formats.
var ErrUnknown = errors.New("unrecognized config: not a sing-box JSON, Clash/mihomo YAML or a list of share links")

// Detect inspects content. prefer is used when both cores fit equally well
// (only possible for share links); empty means sing-box.
func Detect(content []byte, prefer engine.Kind) (Result, error) {
	if !prefer.Valid() {
		prefer = engine.SingBox
	}
	body := bytes.TrimSpace(bytes.TrimPrefix(content, []byte("\xef\xbb\xbf")))
	if len(body) == 0 {
		return Result{}, errors.New("empty config")
	}

	if body[0] == '{' {
		if r, ok := detectJSON(body); ok {
			return r, nil
		}
	}
	if r, ok := detectYAML(body); ok {
		return r, nil
	}
	if links := extractLinks(body); len(links) > 0 {
		return detectLinks(links, prefer), nil
	}
	return Result{}, ErrUnknown
}

// sing-box top-level sections. A mihomo config never has these.
var singBoxKeys = []string{"outbounds", "inbounds", "endpoints", "route", "experimental"}

// Clash/mihomo top-level keys that sing-box never uses.
var clashKeys = []string{
	"proxies", "proxy-groups", "proxy-providers", "rule-providers", "rules",
	"mixed-port", "socks-port", "redir-port", "tproxy-port", "port",
	"external-controller", "allow-lan", "mode", "tun", "sniffer",
}

func detectJSON(body []byte) (Result, bool) {
	var top map[string]json.RawMessage
	if err := json.Unmarshal(body, &top); err != nil {
		// sing-box accepts JSON with comments; fall back to a key scan.
		for _, k := range []string{`"outbounds"`, `"inbounds"`} {
			if bytes.Contains(body, []byte(k)) {
				return Result{Format: SingBoxJSON, Core: engine.SingBox, Reason: "JSON with " + k + " section"}, true
			}
		}
		return Result{}, false
	}
	if k := firstKey(top, singBoxKeys); k != "" {
		return Result{Format: SingBoxJSON, Core: engine.SingBox, Reason: fmt.Sprintf("JSON with %q section", k)}, true
	}
	if k := firstKey(top, clashKeys); k != "" {
		return Result{Format: ClashYAML, Core: engine.Mihomo, Reason: fmt.Sprintf("Clash config in JSON form (%q key)", k)}, true
	}
	return Result{}, false
}

func detectYAML(body []byte) (Result, bool) {
	var top map[string]any
	if err := yaml.Unmarshal(body, &top); err != nil || len(top) == 0 {
		return Result{}, false
	}
	if k := firstKey(top, clashKeys); k != "" {
		return Result{Format: ClashYAML, Core: engine.Mihomo, Reason: fmt.Sprintf("Clash/mihomo YAML (%q key)", k)}, true
	}
	return Result{}, false
}

func firstKey[V any](m map[string]V, keys []string) string {
	for _, k := range keys {
		if _, ok := m[k]; ok {
			return k
		}
	}
	return ""
}

// extractLinks returns share links from a plain or base64 list.
func extractLinks(body []byte) []string {
	if links := scanLinks(string(body)); len(links) > 0 {
		return links
	}
	compact := strings.Join(strings.Fields(string(body)), "")
	for _, enc := range []*base64.Encoding{base64.StdEncoding, base64.RawStdEncoding, base64.URLEncoding, base64.RawURLEncoding} {
		if decoded, err := enc.DecodeString(compact); err == nil {
			if links := scanLinks(string(decoded)); len(links) > 0 {
				return links
			}
		}
	}
	return nil
}

func scanLinks(text string) []string {
	var links []string
	for _, line := range strings.Split(text, "\n") {
		line = strings.TrimSpace(line)
		if _, ok := linkProtocol(line); ok {
			links = append(links, line)
		}
	}
	return links
}

// Link scheme -> protocol name.
var schemes = map[string]string{
	"hysteria2":   "hysteria2",
	"hy2":         "hysteria2",
	"hysteria":    "hysteria",
	"vless":       "vless",
	"vmess":       "vmess",
	"trojan":      "trojan",
	"tuic":        "tuic",
	"ss":          "shadowsocks",
	"ssr":         "shadowsocksr",
	"anytls":      "anytls",
	"naive+https": "naive",
	"naive+quic":  "naive",
	"wireguard":   "wireguard",
	"wg":          "wireguard",
	"socks":       "socks",
	"socks5":      "socks",
	"ssh":         "ssh",
	"mieru":       "mieru",
	"masque":      "masque",
}

func linkProtocol(link string) (string, bool) {
	scheme, _, ok := strings.Cut(link, "://")
	if !ok {
		return "", false
	}
	p, ok := schemes[strings.ToLower(scheme)]
	return p, ok
}

// Which core can run which protocol as a client. Protocols missing from a set
// are not supported by that core.
var support = map[engine.Kind]map[string]bool{
	engine.SingBox: set("hysteria2", "hysteria", "vless", "vmess", "trojan", "tuic", "shadowsocks",
		"anytls", "naive", "wireguard", "socks", "ssh"),
	engine.Mihomo: set("hysteria2", "hysteria", "vless", "vmess", "trojan", "tuic", "shadowsocks",
		"shadowsocksr", "anytls", "wireguard", "socks", "ssh", "mieru", "masque"),
}

func set(items ...string) map[string]bool {
	m := make(map[string]bool, len(items))
	for _, s := range items {
		m[s] = true
	}
	return m
}

// Supports reports whether core k can run protocol p as a client.
func Supports(k engine.Kind, p string) bool { return support[k][p] }

// Share links are turned into a mihomo config (see package convert), so they
// always run on mihomo; Unsupported lists protocols mihomo can't run.
func detectLinks(links []string, _ engine.Kind) Result {
	seen := map[string]bool{}
	for _, l := range links {
		p, _ := linkProtocol(l)
		seen[p] = true
	}
	protocols := make([]string, 0, len(seen))
	for p := range seen {
		protocols = append(protocols, p)
	}
	sort.Strings(protocols)
	r := Result{Format: ShareLinks, Core: engine.Mihomo, Links: links, LinkCount: len(links), Protocols: protocols,
		Unsupported: missing(engine.Mihomo, protocols)}
	r.Reason = "share links are converted to a mihomo config"
	if len(r.Unsupported) > 0 {
		r.Reason += "; skipped: " + strings.Join(r.Unsupported, ", ")
	}
	return r
}

func missing(k engine.Kind, protocols []string) []string {
	var out []string
	for _, p := range protocols {
		if !Supports(k, p) {
			out = append(out, p)
		}
	}
	return out
}
