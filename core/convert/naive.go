package convert

import (
	"fmt"
	"net/url"
	"strconv"
	"strings"
)

// NaiveProxy links (naive+https://user:pass@host:port?params#name, naive+quic://
// for HTTP/3) become mihomo proxies of type "naive". mihomo itself has no such
// protocol: the engine runs these through sing-box (see engine/naive.go) and
// gives mihomo a local SOCKS5 proxy in their place.

// TypeNaive is the proxy type of naive nodes in a generated mihomo config.
const TypeNaive = "naive"

// parseNaive turns one naive link into a mihomo proxy map.
func parseNaive(link string) (map[string]any, error) {
	u, err := url.Parse(strings.TrimSpace(link))
	if err != nil {
		return nil, err
	}
	var quic bool
	switch strings.ToLower(u.Scheme) {
	case "naive+https":
	case "naive+quic":
		quic = true
	default:
		return nil, fmt.Errorf("not a naive link: %s", u.Scheme)
	}
	host := u.Hostname()
	if host == "" {
		return nil, fmt.Errorf("naive link without a server")
	}
	port := 443
	if p := u.Port(); p != "" {
		if port, err = strconv.Atoi(p); err != nil || port <= 0 || port > 65535 {
			return nil, fmt.Errorf("naive link: bad port %q", p)
		}
	}
	name := u.Fragment
	if name == "" {
		name = fmt.Sprintf("%s:%d", host, port)
	}
	p := map[string]any{"name": name, "type": TypeNaive, "server": host, "port": port}
	if u.User != nil {
		p["username"] = u.User.Username()
		if pw, ok := u.User.Password(); ok {
			p["password"] = pw
		}
	}
	if quic {
		p["quic"] = true
	}
	q := u.Query()
	for _, k := range []string{"sni", "peer"} {
		if v := q.Get(k); v != "" {
			p["sni"] = v
			break
		}
	}
	// naive's own format: "Header1: value1\r\nHeader2: value2".
	if h := q.Get("extra-headers"); h != "" {
		headers := map[string]any{}
		for _, line := range strings.Split(strings.ReplaceAll(h, "\r\n", "\n"), "\n") {
			k, v, ok := strings.Cut(line, ":")
			if ok && strings.TrimSpace(k) != "" {
				headers[strings.TrimSpace(k)] = strings.TrimSpace(v)
			}
		}
		if len(headers) > 0 {
			p["extra-headers"] = headers
		}
	}
	if v, err := strconv.Atoi(q.Get("insecure-concurrency")); err == nil && v > 0 {
		p["insecure-concurrency"] = v
	}
	return p, nil
}

func isNaiveLink(line string) bool {
	scheme, _, ok := strings.Cut(strings.TrimSpace(line), "://")
	if !ok {
		return false
	}
	s := strings.ToLower(scheme)
	return s == "naive+https" || s == "naive+quic"
}

// naiveLinks returns the naive proxies of a link list (plain text) and the
// schemes of naive links that could not be read.
func naiveLinks(text string) (proxies []map[string]any, bad map[string]bool) {
	bad = map[string]bool{}
	for _, line := range strings.Split(text, "\n") {
		if !isNaiveLink(line) {
			continue
		}
		p, err := parseNaive(line)
		if err != nil {
			scheme, _, _ := strings.Cut(strings.TrimSpace(line), "://")
			bad[strings.ToLower(scheme)] = true
			continue
		}
		proxies = append(proxies, p)
	}
	return proxies, bad
}

// uniqueName returns name, or name with a number when it's already taken.
func uniqueName(name string, taken map[string]bool) string {
	n := name
	for i := 2; taken[n]; i++ {
		n = fmt.Sprintf("%s %d", name, i)
	}
	taken[n] = true
	return n
}

// mergeNaive inserts the naive proxies into mihomo's list at the places their
// links had. mihomo's converter keeps the order of the links it understands
// and skips the rest, so walking the lines is enough.
func mergeNaive(text string, converted []map[string]any, naive []map[string]any) []map[string]any {
	if len(naive) == 0 {
		return converted
	}
	out := make([]map[string]any, 0, len(converted)+len(naive))
	ci, ni := 0, 0
	for _, line := range strings.Split(text, "\n") {
		line = strings.TrimSpace(line)
		if !strings.Contains(line, "://") {
			continue
		}
		if isNaiveLink(line) {
			if _, err := parseNaive(line); err == nil && ni < len(naive) {
				out = append(out, naive[ni])
				ni++
			}
			continue
		}
		if ci < len(converted) {
			out = append(out, converted[ci])
			ci++
		}
	}
	out = append(out, converted[ci:]...)
	return append(out, naive[ni:]...)
}
