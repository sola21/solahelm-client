package convert

import (
	"fmt"
	"net"
	"net/url"
	"strconv"
	"strings"
)

// mihomo's link converter knows only the obfs and v2ray-plugin plugins of
// ss:// links and silently drops any other, e.g. a SolaHelm panel's ShadowTLS
// v3 link:
//
//	ss://2022-blake3-aes-128-gcm:KEY@host:4443/?plugin=shadow-tls;host=www.example.com;password=P;version=3#name
//
// Without the plugin the node talks plain Shadowsocks to the ShadowTLS port
// and nothing works. ssPlugins reads such plugins from the links and puts
// them back on mihomo's proxies (plugin: shadow-tls, plugin-opts), as in the
// panel's own Clash subscription.

// ssPlugin is a plugin of one ss:// link.
type ssPlugin struct {
	server string
	port   int
	name   string // the link's name (#fragment)
	plugin string // mihomo plugin name
	opts   map[string]any
	fp     string // client-fingerprint
}

// parseSSPlugin returns the plugin of an ss:// link that mihomo's converter
// would drop, or nil.
func parseSSPlugin(line string) *ssPlugin {
	line = strings.TrimSpace(line)
	if !strings.HasPrefix(strings.ToLower(line), "ss://") {
		return nil
	}
	u, err := url.Parse(line)
	if err != nil {
		return nil
	}
	q := u.Query()
	raw := q.Get("plugin")
	if raw == "" {
		return nil
	}
	fields := strings.Split(raw, ";")
	name := strings.ToLower(strings.TrimSpace(fields[0]))
	if name != "shadow-tls" && name != "shadowtls" {
		return nil // obfs / v2ray-plugin: mihomo handles them
	}
	kv := map[string]string{}
	for _, f := range fields[1:] {
		k, v, ok := strings.Cut(f, "=")
		if ok {
			kv[strings.ToLower(strings.TrimSpace(k))] = strings.TrimSpace(v)
		}
	}
	host, port := u.Hostname(), u.Port()
	if host == "" {
		return nil
	}
	p, err := strconv.Atoi(port)
	if err != nil {
		return nil
	}
	opts := map[string]any{"host": kv["host"], "password": kv["password"]}
	version := 3
	if v, err := strconv.Atoi(kv["version"]); err == nil && v > 0 {
		version = v
	}
	opts["version"] = version
	fp := q.Get("fp")
	if fp == "" {
		fp = "chrome" // the panel's ShadowTLS handshake looks like Chrome
	}
	return &ssPlugin{server: host, port: p, name: u.Fragment, plugin: "shadow-tls", opts: opts, fp: fp}
}

// applySSPlugins puts dropped plugins back on the converted ss proxies. A
// proxy is matched by server and port, and by name when several links share
// them.
func applySSPlugins(text string, proxies []map[string]any) {
	var plugins []*ssPlugin
	for _, line := range strings.Split(text, "\n") {
		if p := parseSSPlugin(line); p != nil {
			plugins = append(plugins, p)
		}
	}
	if len(plugins) == 0 {
		return
	}
	used := map[int]bool{}
	for _, pl := range plugins {
		best := -1
		for i, p := range proxies {
			if used[i] || str(p["type"]) != "ss" || !sameHost(str(p["server"]), pl.server) || num(p["port"]) != pl.port {
				continue
			}
			if best < 0 {
				best = i
			}
			if n := str(p["name"]); n == pl.name || strings.HasPrefix(n, pl.name) {
				best = i
				break
			}
		}
		if best < 0 {
			continue
		}
		used[best] = true
		proxies[best]["plugin"] = pl.plugin
		proxies[best]["plugin-opts"] = pl.opts
		if proxies[best]["client-fingerprint"] == nil {
			proxies[best]["client-fingerprint"] = pl.fp
		}
	}
}

func sameHost(a, b string) bool {
	a, b = strings.Trim(a, "[]"), strings.Trim(b, "[]")
	if ia, ib := net.ParseIP(a), net.ParseIP(b); ia != nil && ib != nil {
		return ia.Equal(ib)
	}
	return strings.EqualFold(a, b)
}

func str(v any) string {
	if v == nil {
		return ""
	}
	return fmt.Sprint(v)
}

func num(v any) int {
	switch x := v.(type) {
	case int:
		return x
	case int64:
		return int(x)
	case float64:
		return int(x)
	case string:
		n, _ := strconv.Atoi(x)
		return n
	}
	return 0
}
