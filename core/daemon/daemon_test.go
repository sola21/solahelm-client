package daemon

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"os/exec"
	"testing"
	"time"

	"github.com/sola21/solahelm-client/core/engine"
)

const secret = "0123456789abcdef0123"

func call(t *testing.T, base, method, path string, body any, out any) int {
	t.Helper()
	var r io.Reader
	if body != nil {
		b, _ := json.Marshal(body)
		r = bytes.NewReader(b)
	}
	req, _ := http.NewRequest(method, base+path, r)
	req.Header.Set("Authorization", "Bearer "+secret)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	if out != nil {
		if err := json.NewDecoder(resp.Body).Decode(out); err != nil {
			t.Fatalf("%s %s: decode: %v", method, path, err)
		}
	}
	return resp.StatusCode
}

func TestDaemonFlow(t *testing.T) {
	// A fake panel: Clash subscription with the usual headers.
	clash := "mixed-port: 7890\nallow-lan: true\nmode: rule\nlog-level: warning\n" +
		"tun:\n  enable: true\n  stack: mixed\n  auto-route: true\n" +
		"proxies: []\nrules:\n  - MATCH,DIRECT\n"
	panel := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("User-Agent") != UserAgent {
			http.Error(w, "bad UA", 400)
			return
		}
		w.Header().Set("Subscription-Userinfo", "upload=10; download=2000; total=107374182400; expire=1801440000")
		w.Header().Set("Profile-Title", "base64:0JzQvtGPINC/0LDQvdC10LvRjA==") // "Моя панель"
		io.WriteString(w, clash)
	}))
	defer panel.Close()
	target := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { io.WriteString(w, "pong") }))
	defer target.Close()

	work, _ := os.MkdirTemp("", "solahelm-daemon-test-")
	defer os.RemoveAll(work)
	srv := New(secret, work, map[string]string{"sing-box": "test", "mihomo": "test"})
	api := httptest.NewServer(srv.Handler())
	defer api.Close()
	defer srv.Shutdown()

	// Auth is required.
	resp, _ := http.Get(api.URL + "/status")
	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("no auth: %d", resp.StatusCode)
	}

	var f FetchResult
	if code := call(t, api.URL, "POST", "/fetch", map[string]string{"url": panel.URL + "/sub/x/clash"}, &f); code != 200 {
		t.Fatalf("fetch: %d", code)
	}
	if f.Detect == nil || f.Detect.Core != "mihomo" || f.Total != 107374182400 || f.Download != 2000 || f.Title != "Моя панель" {
		t.Fatalf("fetch result: %+v", f)
	}

	// TUN without admin rights must be refused, not half-started.
	if !isElevated() {
		var e map[string]any
		code := call(t, api.URL, "POST", "/start", StartRequest{Content: f.Content, Mode: ModeTUN}, &e)
		if code != http.StatusForbidden {
			t.Fatalf("tun without admin: %d %v", code, e)
		}
	}

	var st Status
	if code := call(t, api.URL, "POST", "/start", StartRequest{Content: f.Content, Mode: ModePort, Port: -1}, &st); code != 200 {
		t.Fatalf("start: %d", code)
	}
	if !st.Running || st.Core != "mihomo" || st.Port == 0 || st.Controller == "" {
		t.Fatalf("status: %+v", st)
	}

	proxyURL, _ := url.Parse(fmt.Sprintf("http://127.0.0.1:%d", st.Port))
	client := &http.Client{Timeout: 5 * time.Second, Transport: &http.Transport{Proxy: http.ProxyURL(proxyURL)}}
	var got string
	for i := 0; i < 30 && got != "pong"; i++ {
		if r, err := client.Get(target.URL); err == nil {
			b, _ := io.ReadAll(r.Body)
			r.Body.Close()
			got = string(b)
		} else {
			time.Sleep(100 * time.Millisecond)
		}
	}
	if got != "pong" {
		t.Fatal("no traffic through the local port")
	}

	// The core's Clash API is reachable with the secret from /status.
	req, _ := http.NewRequest("GET", "http://"+st.Controller+"/version", nil)
	req.Header.Set("Authorization", "Bearer "+st.ControllerSecret)
	if r, err := http.DefaultClient.Do(req); err != nil || r.StatusCode != 200 {
		t.Fatalf("clash api: %v %v", err, r)
	}

	if code := call(t, api.URL, "POST", "/stop", nil, &st); code != 200 || st.Running {
		t.Fatalf("stop: %d %+v", code, st)
	}
}

func TestValidateAndProfileRules(t *testing.T) {
	links := "hysteria2://pass@vps1.example.org:443?sni=vps1.example.org#DE-hy2\n" +
		"trojan://pass@vps1.example.org:7443?sni=vps1.example.org#DE-trojan\n"
	v := Validate([]byte(links), nil)
	if !v.OK || v.Converted != 2 || v.Detect.Core != "mihomo" {
		t.Fatalf("links: %+v", v)
	}
	pr, err := ProfileRules([]byte(links))
	if err != nil || !pr.Replace || len(pr.Rules) == 0 || len(pr.Targets) < 4 {
		t.Fatalf("profile rules for links: %+v %v", pr, err)
	}
	bad := Validate([]byte(links), &engine.Rules{Lines: []string{"DOMAIN,x.com,NoSuchGroup"}})
	if bad.OK {
		t.Fatal("rule to a missing group accepted")
	}
	good := Validate([]byte(links), &engine.Rules{Lines: []string{"PROCESS-NAME,Telegram.exe,Proxy", "MATCH,DIRECT"}, Replace: true})
	if !good.OK {
		t.Fatalf("good rules rejected: %s", good.Error)
	}
	if v := Validate([]byte("not a config"), nil); v.OK || v.Error == "" {
		t.Fatalf("garbage accepted: %+v", v)
	}
}

// /detach: the core outlives its UI; /attach: a new UI is followed instead.
func TestDetachAttach(t *testing.T) {
	work, _ := os.MkdirTemp("", "solahelm-detach-test-")
	defer os.RemoveAll(work)
	srv := New(secret, work, nil)
	api := httptest.NewServer(srv.Handler())
	defer api.Close()

	ui := exec.Command("powershell", "-NoProfile", "-Command", "Start-Sleep -Seconds 2")
	if err := ui.Start(); err != nil {
		t.Skip("no helper process:", err)
	}
	srv.WatchParent(ui.Process.Pid)
	var st Status
	if code := call(t, api.URL, "POST", "/detach", nil, &st); code != 200 {
		t.Fatalf("detach: %d", code)
	}
	_ = ui.Wait()
	time.Sleep(300 * time.Millisecond)
	select {
	case <-srv.Done():
		t.Fatal("daemon stopped although detached")
	default:
	}

	ui2 := exec.Command("powershell", "-NoProfile", "-Command", "Start-Sleep -Seconds 1")
	if err := ui2.Start(); err != nil {
		t.Fatal(err)
	}
	if code := call(t, api.URL, "POST", "/attach", map[string]int{"pid": ui2.Process.Pid}, &st); code != 200 {
		t.Fatalf("attach: %d", code)
	}
	_ = ui2.Wait()
	select {
	case <-srv.Done():
	case <-time.After(5 * time.Second):
		t.Fatal("daemon did not stop after the attached UI exited")
	}
}
