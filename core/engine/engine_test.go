package engine

import (
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func freePort(t *testing.T) int {
	t.Helper()
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer l.Close()
	return l.Addr().(*net.TCPAddr).Port
}

// Runs sing-box, then mihomo, then sing-box again in one process and checks
// that traffic flows through each core's local proxy and that the Clash API answers.
func TestSwitchCores(t *testing.T) {
	target := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		io.WriteString(w, "pong")
	}))
	defer target.Close()

	singBoxConfig := func(port int) []byte {
		return []byte(fmt.Sprintf(`{
  "log": {"level": "warn"},
  "inbounds": [{"type": "mixed", "tag": "in", "listen": "127.0.0.1", "listen_port": %d}],
  "outbounds": [{"type": "direct", "tag": "direct"}]
}`, port))
	}
	mihomoConfig := func(port int) []byte {
		return []byte(fmt.Sprintf("mixed-port: %d\nbind-address: 127.0.0.1\nallow-lan: false\nlog-level: warning\nmode: rule\nproxies: []\nrules:\n  - MATCH,DIRECT\n", port))
	}

	// Not t.TempDir(): mihomo keeps cache.db open for the life of the process,
	// which makes TempDir's cleanup fail on Windows.
	workDir, err := os.MkdirTemp("", "solahelm-engine-test-")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(workDir)

	var m Manager
	defer m.Stop()
	steps := []struct {
		kind   Kind
		config func(int) []byte
	}{{SingBox, singBoxConfig}, {Mihomo, mihomoConfig}, {SingBox, singBoxConfig}}

	for i, s := range steps {
		proxyPort, apiPort := freePort(t), freePort(t)
		api := fmt.Sprintf("127.0.0.1:%d", apiPort)
		err := m.Start(s.kind, s.config(proxyPort), Options{WorkDir: filepath.Join(workDir, string(s.kind)), Controller: api, Secret: "s3cret"})
		if err != nil {
			t.Fatalf("step %d: start %s: %v", i, s.kind, err)
		}
		if got := m.Running(); got != s.kind {
			t.Fatalf("step %d: Running() = %q", i, got)
		}

		proxyURL, _ := url.Parse(fmt.Sprintf("http://127.0.0.1:%d", proxyPort))
		client := &http.Client{Timeout: 5 * time.Second, Transport: &http.Transport{Proxy: http.ProxyURL(proxyURL)}}
		body := retryGet(t, client, target.URL, nil)
		if body != "pong" {
			t.Fatalf("step %d (%s): body through proxy = %q", i, s.kind, body)
		}

		// Same API call works on both cores.
		raw := retryGet(t, http.DefaultClient, "http://"+api+"/version", map[string]string{"Authorization": "Bearer s3cret"})
		var v map[string]any
		if err := json.Unmarshal([]byte(raw), &v); err != nil || v["version"] == nil {
			t.Fatalf("step %d (%s): /version = %q", i, s.kind, raw)
		}
		t.Logf("step %d: %s ok, /version = %s", i, s.kind, raw)
	}
	if err := m.Stop(); err != nil {
		t.Fatal(err)
	}
	if m.Running() != "" {
		t.Fatal("still running after Stop")
	}
}

// ProxyOnly must strip TUN (which would need admin rights and reroute the
// host) and MixedPort must move the local port, for both cores.
func TestProxyOnlyAndPortOverride(t *testing.T) {
	target := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		io.WriteString(w, "pong")
	}))
	defer target.Close()

	workDir, err := os.MkdirTemp("", "solahelm-proxyonly-test-")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(workDir)

	configs := map[Kind]string{
		SingBox: `{
  "log": {"level": "warn"},
  "inbounds": [
    {"type": "tun", "tag": "tun-in", "address": ["172.19.0.1/30"], "auto_route": true, "strict_route": true},
    {"type": "mixed", "tag": "mixed-in", "listen": "0.0.0.0", "listen_port": 1, "set_system_proxy": true}
  ],
  "outbounds": [{"type": "direct", "tag": "direct"}],
  "route": {"rules": [{"inbound": ["tun-in"], "action": "sniff"}], "auto_detect_interface": true}
}`,
		Mihomo: "mixed-port: 1\nallow-lan: true\nbind-address: '*'\nmode: rule\nlog-level: warning\n" +
			"tun:\n  enable: true\n  stack: gvisor\n  auto-route: true\n" +
			"dns:\n  enable: true\n  listen: 0.0.0.0:1053\n" +
			"proxies: []\nrules:\n  - MATCH,DIRECT\n",
	}

	var m Manager
	defer m.Stop()
	for _, kind := range []Kind{SingBox, Mihomo} {
		port := freePort(t)
		err := m.Start(kind, []byte(configs[kind]), Options{
			WorkDir:   filepath.Join(workDir, string(kind)),
			ProxyOnly: true,
			MixedPort: port,
		})
		if err != nil {
			t.Fatalf("%s: %v", kind, err)
		}
		proxyURL, _ := url.Parse(fmt.Sprintf("http://127.0.0.1:%d", port))
		client := &http.Client{Timeout: 5 * time.Second, Transport: &http.Transport{Proxy: http.ProxyURL(proxyURL)}}
		if body := retryGet(t, client, target.URL, nil); body != "pong" {
			t.Fatalf("%s: body = %q", kind, body)
		}
	}
}

func retryGet(t *testing.T, c *http.Client, u string, headers map[string]string) string {
	t.Helper()
	var lastErr error
	for i := 0; i < 30; i++ {
		req, _ := http.NewRequest(http.MethodGet, u, nil)
		for k, v := range headers {
			req.Header.Set(k, v)
		}
		resp, err := c.Do(req)
		if err == nil {
			b, _ := io.ReadAll(resp.Body)
			resp.Body.Close()
			if resp.StatusCode == http.StatusOK {
				return string(b)
			}
			lastErr = fmt.Errorf("%s: %s", resp.Status, b)
		} else {
			lastErr = err
		}
		time.Sleep(100 * time.Millisecond)
	}
	t.Fatalf("GET %s: %v", u, lastErr)
	return ""
}

// A user rule must win over the profile's own rules, in both cores.
func TestUserRules(t *testing.T) {
	target := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		io.WriteString(w, "pong")
	}))
	defer target.Close()
	workDir, err := os.MkdirTemp("", "solahelm-rules-test-")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(workDir)

	configs := map[Kind]string{
		SingBox: `{"log":{"level":"warn"},
  "inbounds":[{"type":"mixed","tag":"in","listen":"127.0.0.1","listen_port":1}],
  "outbounds":[{"type":"selector","tag":"proxy","outbounds":["d"]},{"type":"direct","tag":"d"}],
  "route":{"final":"proxy"}}`,
		Mihomo: "mixed-port: 1\nmode: rule\nlog-level: warning\nproxies: []\n" +
			"proxy-groups:\n  - {name: Main, type: select, proxies: [DIRECT]}\nrules:\n  - MATCH,Main\n",
	}
	var m Manager
	defer m.Stop()
	for _, kind := range []Kind{SingBox, Mihomo} {
		for _, block := range []bool{false, true} {
			var rules *Rules
			if block {
				rules = &Rules{Lines: []string{"IP-CIDR,127.0.0.1/32,REJECT,no-resolve"}}
			}
			port := freePort(t)
			if err := m.Start(kind, []byte(configs[kind]), Options{
				WorkDir: filepath.Join(workDir, string(kind)), ProxyOnly: true, MixedPort: port, Rules: rules,
			}); err != nil {
				t.Fatalf("%s block=%v: %v", kind, block, err)
			}
			proxyURL, _ := url.Parse(fmt.Sprintf("http://127.0.0.1:%d", port))
			client := &http.Client{Timeout: 3 * time.Second, Transport: &http.Transport{Proxy: http.ProxyURL(proxyURL)}}
			var ok bool
			for i := 0; i < 15 && !ok; i++ {
				if resp, err := client.Get(target.URL); err == nil {
					b, _ := io.ReadAll(resp.Body)
					resp.Body.Close()
					ok = resp.StatusCode == 200 && string(b) == "pong"
				}
				if !ok {
					time.Sleep(100 * time.Millisecond)
				}
			}
			if ok == block {
				t.Fatalf("%s: block=%v but request succeeded=%v", kind, block, ok)
			}
		}
	}
}

func TestValidate(t *testing.T) {
	if err := Validate(SingBox, []byte(`{"outbounds":[{"type":"direct","tag":"d"}]}`)); err != nil {
		t.Fatal(err)
	}
	if err := Validate(SingBox, []byte(`{"outbounds":[{"type":"no-such-type"}]}`)); err == nil {
		t.Fatal("sing-box: bad outbound type accepted")
	}
	if err := Validate(Mihomo, []byte("proxies: []\nrules:\n  - MATCH,DIRECT\n")); err != nil {
		t.Fatal(err)
	}
	if err := Validate(Mihomo, []byte("proxies:\n  - {name: a, type: no-such-type, server: x, port: 1}\n")); err == nil {
		t.Fatal("mihomo: bad proxy type accepted")
	}
}

func TestRuleHelpers(t *testing.T) {
	// mihomo: replace the whole list, keep the targets.
	y := []byte(`proxies:
  - {name: n1, type: direct}
proxy-groups:
  - {name: G, type: select, proxies: [n1]}
rules:
  - DOMAIN,a.com,G
  - MATCH,DIRECT
`)
	lines, targets, err := MihomoProfileRules(y)
	if err != nil || len(lines) != 2 || len(targets) != 2 || targets[0] != "G" {
		t.Fatalf("mihomo profile rules: %v %v %v", lines, targets, err)
	}
	out, err := injectMihomoRules(y, &Rules{Lines: []string{"PROCESS-NAME,Telegram.exe,G", "MATCH,G"}, Replace: true})
	if err != nil {
		t.Fatal(err)
	}
	lines, _, _ = MihomoProfileRules(out)
	if len(lines) != 2 || lines[0] != "PROCESS-NAME,Telegram.exe,G" {
		t.Fatalf("replaced rules: %v", lines)
	}
	if err := ValidateWithRules(Mihomo, y, &Rules{Lines: []string{"DOMAIN-SUFFIX,x.com,NoSuchGroup"}}); err == nil {
		t.Fatal("mihomo: rule to a missing group accepted")
	}

	// sing-box: translated rules go to existing tags only.
	j := []byte(`{"outbounds":[{"type":"selector","tag":"proxy","outbounds":["d"]},{"type":"direct","tag":"d"}],
	  "route":{"rules":[{"action":"sniff"},{"rule_set":["geosite-ru"],"outbound":"d"}],"final":"proxy"}}`)
	lines, targets, err = SingBoxProfileRules(j)
	if err != nil || len(lines) != 3 || targets[0] != "proxy" {
		t.Fatalf("sing-box profile rules: %v %v %v", lines, targets, err)
	}
	if err := ValidateWithRules(SingBox, j, &Rules{Lines: []string{"DOMAIN-SUFFIX,youtube.com,proxy", "DST-PORT,22,DIRECT", "MATCH,d"}}); err != nil {
		t.Fatal(err)
	}
	if err := ValidateWithRules(SingBox, j, &Rules{Lines: []string{"GEOIP,RU,DIRECT"}}); err == nil {
		t.Fatal("sing-box: GEOIP accepted")
	}
	if err := ValidateWithRules(SingBox, j, &Rules{Lines: []string{"DOMAIN,x.com,missing"}}); err == nil {
		t.Fatal("sing-box: missing outbound accepted")
	}
}
