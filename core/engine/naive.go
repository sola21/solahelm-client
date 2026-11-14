package engine

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net"
	"os"
	"strings"

	box "github.com/sagernet/sing-box"
	"github.com/sagernet/sing-box/experimental/deprecated"
	"github.com/sagernet/sing-box/log"
	"github.com/sagernet/sing-box/option"
	sjson "github.com/sagernet/sing/common/json"
	"github.com/sagernet/sing/service"
	"go.yaml.in/yaml/v3"
)

// mihomo has no NaiveProxy. A mihomo config may still list proxies of type
// "naive" (configs made from share links do, see package convert): the engine
// runs them in a sing-box instance inside this process and gives mihomo a
// local SOCKS5 proxy for each, so mihomo's rules, groups and latency tests work
// as for any other proxy:
//
//	mihomo -> SOCKS5 127.0.0.1:<port> (user n<i>) -> sing-box naive n<i> -> server
//
// naive's own connections and DNS go through mihomo's dialer and resolver
// (naive_dns.go), like mihomo's other proxies.

// naiveType is the proxy type of naive nodes in a mihomo config.
const naiveType = "naive"

type naiveNode struct {
	Name        string
	Server      string
	Port        int
	Username    string
	Password    string
	SNI         string
	QUIC        bool
	Headers     map[string]string
	Concurrency int
}

func naiveNodeFrom(p map[string]any) (naiveNode, error) {
	n := naiveNode{
		Name:     str(p["name"]),
		Server:   str(p["server"]),
		Username: str(p["username"]),
		Password: str(p["password"]),
		SNI:      str(p["sni"]),
	}
	if n.SNI == "" {
		n.SNI = str(p["servername"])
	}
	n.Port = num(p["port"])
	n.QUIC, _ = p["quic"].(bool)
	n.Concurrency = num(p["insecure-concurrency"])
	if h, ok := p["extra-headers"].(map[string]any); ok {
		n.Headers = map[string]string{}
		for k, v := range h {
			n.Headers[k] = str(v)
		}
	}
	switch {
	case n.Name == "":
		return n, fmt.Errorf("naive proxy without a name")
	case n.Server == "":
		return n, fmt.Errorf("naive proxy %q: no server", n.Name)
	case n.Port <= 0 || n.Port > 65535:
		return n, fmt.Errorf("naive proxy %q: bad port", n.Name)
	}
	return n, nil
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
		var n int
		_, _ = fmt.Sscan(x, &n)
		return n
	}
	return 0
}

// naiveBridge is the sing-box instance behind a config's naive proxies.
type naiveBridge struct {
	nodes      []naiveNode
	secret     string
	bridgePort int // sing-box SOCKS5 inbound, mihomo's naive proxies point here

	instance *box.Box
	cancel   context.CancelFunc
}

// Names lists the naive proxies.
func (b *naiveBridge) Names() []string {
	if b == nil {
		return nil
	}
	out := make([]string, len(b.nodes))
	for i, n := range b.nodes {
		out[i] = n.Name
	}
	return out
}

// rewriteNaive replaces the naive proxies of a mihomo config with SOCKS5
// proxies to the bridge. With no naive proxies it returns raw unchanged and a
// nil bridge. With live=false (validation) no port is taken.
func rewriteNaive(raw []byte, live bool) ([]byte, *naiveBridge, error) {
	if !strings.Contains(string(raw), naiveType) {
		return raw, nil, nil
	}
	var cfg map[string]any
	if err := yaml.Unmarshal(raw, &cfg); err != nil {
		return nil, nil, err
	}
	proxies, _ := cfg["proxies"].([]any)
	b := &naiveBridge{bridgePort: 1, secret: "check"}
	var at []int
	for i, v := range proxies {
		p, ok := v.(map[string]any)
		if !ok || !strings.EqualFold(str(p["type"]), naiveType) {
			continue
		}
		n, err := naiveNodeFrom(p)
		if err != nil {
			return nil, nil, err
		}
		b.nodes = append(b.nodes, n)
		at = append(at, i)
	}
	if len(b.nodes) == 0 {
		return raw, nil, nil
	}
	if live {
		var err error
		if b.bridgePort, err = pickPort(); err != nil {
			return nil, nil, err
		}
		var k [16]byte
		_, _ = rand.Read(k[:])
		b.secret = hex.EncodeToString(k[:])
	}
	for j, i := range at {
		proxies[i] = map[string]any{
			"name":     b.nodes[j].Name,
			"type":     "socks5",
			"server":   "127.0.0.1",
			"port":     b.bridgePort,
			"username": fmt.Sprintf("n%d", j),
			"password": b.secret,
			"udp":      true, // UDP over TCP through naive
		}
	}
	out, err := yaml.Marshal(cfg)
	if err != nil {
		return nil, nil, err
	}
	return out, b, nil
}

func pickPort() (int, error) {
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return 0, err
	}
	defer l.Close()
	return l.Addr().(*net.TCPAddr).Port, nil
}

// singBoxConfig is the bridge's sing-box config.
func (b *naiveBridge) singBoxConfig() ([]byte, error) {
	users := make([]any, 0, len(b.nodes))
	outbounds := make([]any, 0, len(b.nodes)+1)
	rules := make([]any, 0, len(b.nodes))
	for i, n := range b.nodes {
		tag := fmt.Sprintf("n%d", i)
		users = append(users, map[string]any{"username": tag, "password": b.secret})
		tls := map[string]any{"enabled": true}
		if n.SNI != "" {
			tls["server_name"] = n.SNI
		}
		o := map[string]any{
			"type": "naive", "tag": tag,
			"server": n.Server, "server_port": n.Port,
			"username": n.Username, "password": n.Password,
			"tls":          tls,
			"udp_over_tcp": map[string]any{"enabled": true},
			"detour":       "out",
		}
		if n.QUIC {
			o["quic"] = true
		}
		if len(n.Headers) > 0 {
			o["extra_headers"] = n.Headers
		}
		if n.Concurrency > 0 {
			o["insecure_concurrency"] = n.Concurrency
		}
		outbounds = append(outbounds, o)
		rules = append(rules, map[string]any{"auth_user": []string{tag}, "outbound": tag})
	}
	outbounds = append(outbounds, map[string]any{"type": outboundTypeMihomo, "tag": "out"})
	cfg := map[string]any{
		"log": map[string]any{"level": "warn"},
		// The servers' names: mihomo's resolver for proxy servers (naive_dns.go).
		"dns": map[string]any{
			"servers": []any{map[string]any{"type": dnsTypeMihomo, "tag": "dns"}},
		},
		"inbounds": []any{map[string]any{
			"type": "socks", "tag": "in", "listen": "127.0.0.1", "listen_port": b.bridgePort, "users": users,
		}},
		"outbounds": outbounds,
		"route": map[string]any{
			"rules":                   rules,
			"final":                   "n0", // unreachable: every user has a rule
			"default_domain_resolver": "dns",
		},
	}
	return json.Marshal(cfg)
}

// start runs the bridge.
func (b *naiveBridge) start(workDir string) error {
	raw, err := b.singBoxConfig()
	if err != nil {
		return err
	}
	ctx := context.Background()
	if workDir != "" {
		_ = os.MkdirAll(workDir, 0o755)
	}
	ctx = bridgeContext(service.ContextWith(ctx, deprecated.NewStderrManager(log.StdLogger())))
	parsed, err := sjson.UnmarshalExtendedContext[option.Options](ctx, raw)
	if err != nil {
		return err
	}
	ctx, cancel := context.WithCancel(service.ExtendContext(ctx))
	instance, err := box.New(box.Options{Context: ctx, Options: parsed})
	if err != nil {
		cancel()
		return fmt.Errorf("naive: %w", err)
	}
	if err := instance.Start(); err != nil {
		_ = instance.Close()
		cancel()
		return fmt.Errorf("naive: %w", err)
	}
	b.instance, b.cancel = instance, cancel
	return nil
}

func (b *naiveBridge) stop() {
	if b == nil || b.instance == nil {
		return
	}
	_ = b.instance.Close()
	b.cancel()
	b.instance = nil
}
