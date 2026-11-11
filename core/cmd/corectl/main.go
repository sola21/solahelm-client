// corectl runs a sing-box or mihomo config, picking the core automatically.
//
//	corectl detect [-prefer sing-box|mihomo] <file|url>
//	corectl run    [flags] <file|url>   run until Ctrl+C
//	corectl test   [flags] <file|url>   start, measure every proxy, stop
//	corectl version
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"os/signal"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"syscall"
	"text/tabwriter"
	"time"

	mihomoC "github.com/metacubex/mihomo/constant"
	singboxC "github.com/sagernet/sing-box/constant"

	"github.com/sola21/solahelm-client/core/convert"
	"github.com/sola21/solahelm-client/core/detect"
	"github.com/sola21/solahelm-client/core/engine"
)

const userAgent = "solahelm-client/0.1"

func main() {
	if len(os.Args) < 2 {
		usage()
	}
	switch os.Args[1] {
	case "detect":
		cmdDetect(os.Args[2:])
	case "run":
		cmdRun(os.Args[2:])
	case "test":
		cmdTest(os.Args[2:])
	case "serve":
		cmdServe(os.Args[2:])
	case "version":
		fmt.Printf("sing-box %s\nmihomo   %s\n", singboxC.Version, mihomoC.Version)
	default:
		usage()
	}
}

func usage() {
	fmt.Fprintln(os.Stderr, `usage:
  corectl detect [-prefer sing-box|mihomo] <file|url>
  corectl run  [flags] <file|url>
  corectl test [flags] [-probe URL] [-timeout 5s] <file|url>
  corectl version

flags for run/test:
  -core auto|sing-box|mihomo   -prefer sing-box|mihomo
  -controller 127.0.0.1:9090   -secret s   -workdir dir
  -proxy-only                  drop TUN, listen on 127.0.0.1 only (test: on by default)
  -loopback                    listen on 127.0.0.1 only but keep TUN
  -tun-stack gvisor|system|mixed
  -port N                      local mixed (HTTP+SOCKS) port
  -routing all|ru-direct       links only: everything via VPN, or Russian sites direct
  -duration 40s                (run) stop automatically`)
	os.Exit(2)
}

func cmdDetect(args []string) {
	fs := flag.NewFlagSet("detect", flag.ExitOnError)
	prefer := fs.String("prefer", "sing-box", "core to use when both fit")
	fs.Parse(args)
	if fs.NArg() != 1 {
		usage()
	}
	body := mustLoad(fs.Arg(0))
	r, err := detect.Detect(body, engine.Kind(*prefer))
	if err != nil {
		fatal(err)
	}
	r.Links = nil
	out, _ := json.MarshalIndent(r, "", "  ")
	fmt.Println(string(out))
}

type runFlags struct {
	core, prefer, controller, secret, workdir *string
	proxyOnly, loopback                       *bool
	port                                      *int
	tunStack                                  *string
	dnsMode, dnsRemote, dnsDirect             *string
	routing                                   *string
}

func addRunFlags(fs *flag.FlagSet, proxyOnlyDefault bool, controllerDefault string, portDefault int) runFlags {
	return runFlags{
		core:       fs.String("core", "auto", "auto, sing-box or mihomo"),
		prefer:     fs.String("prefer", "sing-box", "core to use when both fit"),
		controller: fs.String("controller", controllerDefault, "Clash API listen address (empty: keep config value)"),
		secret:     fs.String("secret", "", "Clash API secret"),
		workdir:    fs.String("workdir", defaultWorkDir(), "state directory for the core"),
		proxyOnly:  fs.Bool("proxy-only", proxyOnlyDefault, "drop TUN and system proxy, listen on 127.0.0.1 only"),
		port:       fs.Int("port", portDefault, "local mixed port (0: keep config value)"),
		loopback:   fs.Bool("loopback", proxyOnlyDefault, "listen on 127.0.0.1 only, no allow-lan (keeps TUN)"),
		tunStack:   fs.String("tun-stack", "", "override TUN stack: gvisor, system or mixed"),
		dnsMode:    fs.String("dns-mode", "", "mihomo: replace DNS: vpn (needs -dns-remote, -dns-direct), direct (needs -dns-direct) or system"),
		dnsRemote:  fs.String("dns-remote", "", "mihomo: replace DNS, comma list of remote resolvers (needs -dns-direct)"),
		dnsDirect:  fs.String("dns-direct", "", "mihomo: plain resolvers for proxy servers and direct traffic"),
		routing:    fs.String("routing", "all", "links only: routing template, all or ru-direct"),
	}
}

// start loads src, picks the core and starts it.
func start(m *engine.Manager, f runFlags, src string) engine.Kind {
	body := mustLoad(src)
	kind := engine.Kind(*f.core)
	if *f.core == "auto" {
		r, err := detect.Detect(body, engine.Kind(*f.prefer))
		if err != nil {
			fatal(err)
		}
		if r.Format == detect.ShareLinks {
			conv, err := convert.LinksToMihomo(body, *f.routing)
			if err != nil {
				fatal(err)
			}
			body = conv.YAML
			fmt.Fprintf(os.Stderr, "corectl: %d links -> mihomo config with %d proxies (skipped: %s)\n",
				len(r.Links), conv.Proxies, strings.Join(conv.Skipped, ", "))
		}
		kind = r.Core
		fmt.Fprintf(os.Stderr, "corectl: %s -> %s (%s)\n", r.Format, r.Core, r.Reason)
	} else if !kind.Valid() {
		fatal(fmt.Errorf("unknown core %q", *f.core))
	}
	var tuning *engine.Tuning
	if *f.dnsMode != "" || (*f.dnsRemote != "" && *f.dnsDirect != "") {
		d := &engine.DNSOverride{Mode: *f.dnsMode}
		if *f.dnsRemote != "" {
			d.Remote = strings.Split(*f.dnsRemote, ",")
		}
		if *f.dnsDirect != "" {
			d.Direct = strings.Split(*f.dnsDirect, ",")
		}
		tuning = &engine.Tuning{DNS: d}
	}
	err := m.Start(kind, body, engine.Options{
		Tuning:       tuning,
		WorkDir:      filepath.Join(*f.workdir, string(kind)),
		Controller:   *f.controller,
		Secret:       *f.secret,
		ProxyOnly:    *f.proxyOnly,
		LoopbackOnly: *f.loopback,
		TUNStack:     *f.tunStack,
		MixedPort:    *f.port,
	})
	if err != nil {
		fatal(err)
	}
	return kind
}

func cmdRun(args []string) {
	fs := flag.NewFlagSet("run", flag.ExitOnError)
	f := addRunFlags(fs, false, "127.0.0.1:9090", 0)
	duration := fs.Duration("duration", 0, "stop automatically after this long (0: run until Ctrl+C)")
	fs.Parse(args)
	if fs.NArg() != 1 {
		usage()
	}
	var m engine.Manager
	kind := start(&m, f, fs.Arg(0))
	msg := fmt.Sprintf("corectl: %s running", kind)
	if *f.controller != "" {
		msg += fmt.Sprintf(", Clash API at http://%s", *f.controller)
	}
	if *f.port != 0 {
		msg += fmt.Sprintf(", proxy at 127.0.0.1:%d", *f.port)
	}
	var timeout <-chan time.Time
	if *duration > 0 {
		msg += fmt.Sprintf(", auto-stop in %s", *duration)
		timeout = time.After(*duration)
	}
	fmt.Fprintln(os.Stderr, msg+" (Ctrl+C to stop)")

	sig := make(chan os.Signal, 1)
	signal.Notify(sig, os.Interrupt, syscall.SIGTERM)
	select {
	case <-sig:
	case <-timeout:
	}
	fmt.Fprintln(os.Stderr, "corectl: stopping")
	if err := m.Stop(); err != nil {
		fatal(err)
	}
}

// cmdTest starts the config in proxy-only mode, asks the core (through the
// Clash API, same for both cores) to measure every proxy, fetches the exit IP
// through the local port and stops.
func cmdTest(args []string) {
	fs := flag.NewFlagSet("test", flag.ExitOnError)
	f := addRunFlags(fs, true, "127.0.0.1:19090", 17890)
	probe := fs.String("probe", "https://www.gstatic.com/generate_204", "URL used for delay tests")
	timeout := fs.Duration("timeout", 5*time.Second, "delay test timeout")
	ipURL := fs.String("ip-url", "https://api.ipify.org", "URL that returns the exit IP")
	fs.Parse(args)
	if fs.NArg() != 1 || *f.controller == "" {
		usage()
	}
	var m engine.Manager
	kind := start(&m, f, fs.Arg(0))
	defer m.Stop()

	api := &clashAPI{base: "http://" + *f.controller, secret: *f.secret}
	var version map[string]any
	for i := 0; i < 50; i++ {
		if err := api.get("/version", &version); err == nil {
			break
		}
		time.Sleep(200 * time.Millisecond)
	}
	if version == nil {
		fatal(fmt.Errorf("Clash API at %s did not answer", *f.controller))
	}
	fmt.Printf("core: %s %v\n\n", kind, version["version"])

	var all struct {
		Proxies map[string]struct {
			Type string   `json:"type"`
			All  []string `json:"all"`
			Now  string   `json:"now"`
		} `json:"proxies"`
	}
	if err := api.get("/proxies", &all); err != nil {
		fatal(err)
	}
	var leaves []string
	for name, p := range all.Proxies {
		if len(p.All) == 0 && !builtin[strings.ToLower(p.Type)] {
			leaves = append(leaves, name)
		}
	}
	sort.Strings(leaves)

	type result struct {
		name, typ, delay string
		ok               bool
	}
	results := make([]result, len(leaves))
	var wg sync.WaitGroup
	sem := make(chan struct{}, 4)
	for i, name := range leaves {
		wg.Add(1)
		go func() {
			defer wg.Done()
			sem <- struct{}{}
			defer func() { <-sem }()
			r := result{name: name, typ: all.Proxies[name].Type}
			var d struct {
				Delay   int    `json:"delay"`
				Message string `json:"message"`
			}
			q := url.Values{"url": {*probe}, "timeout": {fmt.Sprint(timeout.Milliseconds())}}
			err := api.get("/proxies/"+url.PathEscape(name)+"/delay?"+q.Encode(), &d)
			switch {
			case err != nil:
				r.delay = err.Error()
			case d.Delay > 0:
				r.delay, r.ok = fmt.Sprintf("%d ms", d.Delay), true
			default:
				r.delay = d.Message
			}
			results[i] = r
		}()
	}
	wg.Wait()

	tw := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
	fmt.Fprintln(tw, "PROXY\tTYPE\tDELAY")
	okCount := 0
	for _, r := range results {
		mark := "FAIL "
		if r.ok {
			mark = ""
			okCount++
		}
		fmt.Fprintf(tw, "%s\t%s\t%s%s\n", r.name, r.typ, mark, r.delay)
	}
	tw.Flush()
	fmt.Printf("\n%d of %d proxies answered\n", okCount, len(results))

	for name, p := range all.Proxies {
		if len(p.All) > 0 && p.Now != "" && name != "GLOBAL" {
			fmt.Printf("group %q -> %s\n", name, p.Now)
		}
	}
	if *f.port != 0 {
		proxyURL, _ := url.Parse(fmt.Sprintf("http://127.0.0.1:%d", *f.port))
		c := &http.Client{Timeout: 15 * time.Second, Transport: &http.Transport{Proxy: http.ProxyURL(proxyURL)}}
		resp, err := c.Get(*ipURL)
		if err != nil {
			fmt.Printf("exit IP via 127.0.0.1:%d: error: %v\n", *f.port, err)
		} else {
			b, _ := io.ReadAll(io.LimitReader(resp.Body, 256))
			resp.Body.Close()
			fmt.Printf("exit IP via 127.0.0.1:%d: %s\n", *f.port, strings.TrimSpace(string(b)))
		}
	}
	if okCount == 0 {
		m.Stop()
		os.Exit(1)
	}
}

// Built-in Clash API proxy types that are not real servers.
var builtin = map[string]bool{
	"direct": true, "reject": true, "rejectdrop": true, "compatible": true, "pass": true,
	"passrule": true, "dns": true, "block": true,
}

type clashAPI struct{ base, secret string }

func (a *clashAPI) get(path string, out any) error {
	req, err := http.NewRequest(http.MethodGet, a.base+path, nil)
	if err != nil {
		return err
	}
	if a.secret != "" {
		req.Header.Set("Authorization", "Bearer "+a.secret)
	}
	resp, err := (&http.Client{Timeout: 30 * time.Second}).Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	b, err := io.ReadAll(io.LimitReader(resp.Body, 8<<20))
	if err != nil {
		return err
	}
	if resp.StatusCode != http.StatusOK {
		var e struct {
			Message string `json:"message"`
		}
		if json.Unmarshal(b, &e) == nil && e.Message != "" {
			return fmt.Errorf("%s", e.Message)
		}
		return fmt.Errorf("%s", resp.Status)
	}
	return json.Unmarshal(b, out)
}

func defaultWorkDir() string {
	if d, err := os.UserConfigDir(); err == nil {
		return filepath.Join(d, "solahelm-client")
	}
	return "solahelm-client-data"
}

// mustLoad reads a local file or downloads a URL.
func mustLoad(src string) []byte {
	if !strings.HasPrefix(src, "http://") && !strings.HasPrefix(src, "https://") {
		b, err := os.ReadFile(src)
		if err != nil {
			fatal(err)
		}
		return b
	}
	req, err := http.NewRequest(http.MethodGet, src, nil)
	if err != nil {
		fatal(err)
	}
	req.Header.Set("User-Agent", userAgent)
	resp, err := (&http.Client{Timeout: 30 * time.Second}).Do(req)
	if err != nil {
		fatal(err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		fatal(fmt.Errorf("GET %s: %s", redact(src), resp.Status))
	}
	if info := resp.Header.Get("Subscription-Userinfo"); info != "" {
		fmt.Fprintf(os.Stderr, "corectl: subscription-userinfo: %s\n", info)
	}
	b, err := io.ReadAll(io.LimitReader(resp.Body, 16<<20))
	if err != nil {
		fatal(err)
	}
	return b
}

// redact hides subscription tokens in messages.
func redact(u string) string {
	if i := strings.Index(u, "/sub/"); i >= 0 {
		rest := u[i+5:]
		if j := strings.IndexByte(rest, '/'); j >= 0 {
			return u[:i+5] + "…" + rest[j:]
		}
		return u[:i+5] + "…"
	}
	return u
}

func fatal(err error) {
	fmt.Fprintln(os.Stderr, "corectl:", err)
	os.Exit(1)
}
