// Package daemon is the control API the UI talks to. It runs in its own
// process (solahelm-core), which can be elevated for TUN while the UI is not.
//
// Every request needs "Authorization: Bearer <secret>". Endpoints (JSON):
//
//	GET  /status            current state
//	POST /fetch  {url}      download a subscription, detect it, read userinfo
//	POST /detect {content}  detect a config body
//	POST /start  {...}      start a core (stops the running one first)
//	POST /stop              stop the core and restore the system proxy
//	POST /shutdown          stop and exit the process
//
// Proxies, delays, traffic and connections come from the core's own Clash API,
// whose address and secret /status returns.
package daemon

import (
	"context"
	"crypto/rand"
	"crypto/subtle"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"mime"
	"net"
	"net/http"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/sola21/solahelm-client/core/detect"
	"github.com/sola21/solahelm-client/core/engine"
)

// Mode is how traffic gets into the core.
type Mode string

const (
	ModeTUN         Mode = "tun"          // whole system, needs admin
	ModeSystemProxy Mode = "system-proxy" // apps that honor the system proxy
	ModePort        Mode = "port"         // only a local port, nothing else changes
)

type systemProxy interface {
	Enable(addr string) error
	Disable() error
}

// Status is what /status, /start and /stop return.
type Status struct {
	Running          bool              `json:"running"`
	Core             engine.Kind       `json:"core,omitempty"`
	Mode             Mode              `json:"mode,omitempty"`
	Port             int               `json:"port,omitempty"`
	Controller       string            `json:"controller,omitempty"`
	ControllerSecret string            `json:"controllerSecret,omitempty"`
	StartedAt        *time.Time        `json:"startedAt,omitempty"`
	Detect           *detect.Result    `json:"detect,omitempty"`
	Elevated         bool              `json:"elevated"`
	Error            string            `json:"error,omitempty"`
	Version          map[string]string `json:"version"`
}

// StartRequest starts a core with a config body.
type StartRequest struct {
	Content  string `json:"content"`
	Core     string `json:"core"`   // auto (default), sing-box, mihomo
	Prefer   string `json:"prefer"` // core for share links when both fit
	Mode     Mode   `json:"mode"`
	Port     int    `json:"port"`     // local mixed port; 0 = 7890 or the next free one
	TUNStack string `json:"tunStack"` // default gvisor
}

// FetchResult is a downloaded subscription.
type FetchResult struct {
	Content  string         `json:"content"`
	Detect   *detect.Result `json:"detect,omitempty"`
	Error    string         `json:"error,omitempty"` // detection error, content still returned
	Title    string         `json:"title,omitempty"`
	Upload   int64          `json:"upload"`
	Download int64          `json:"download"`
	Total    int64          `json:"total"`  // 0 = unlimited
	Expire   int64          `json:"expire"` // unix seconds, 0 = never
	Interval int            `json:"updateIntervalHours,omitempty"`
}

// Server holds one core and serves the control API.
type Server struct {
	Secret   string
	WorkDir  string
	Versions map[string]string

	mu      sync.Mutex
	mgr     engine.Manager
	status  Status
	sysprox systemProxy
	quit    chan struct{}
	once    sync.Once
}

func New(secret, workDir string, versions map[string]string) *Server {
	return &Server{Secret: secret, WorkDir: workDir, Versions: versions, sysprox: newSystemProxy(), quit: make(chan struct{})}
}

// Done is closed after /shutdown.
func (s *Server) Done() <-chan struct{} { return s.quit }

// Handler returns the HTTP API.
func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /status", func(w http.ResponseWriter, r *http.Request) { s.reply(w, s.Status(), nil) })
	mux.HandleFunc("POST /start", func(w http.ResponseWriter, r *http.Request) {
		var req StartRequest
		if err := decode(r, &req); err != nil {
			s.reply(w, nil, err)
			return
		}
		st, err := s.Start(req)
		s.reply(w, st, err)
	})
	mux.HandleFunc("POST /stop", func(w http.ResponseWriter, r *http.Request) {
		s.reply(w, s.Stop(), nil)
	})
	mux.HandleFunc("POST /detect", func(w http.ResponseWriter, r *http.Request) {
		var req struct {
			Content string `json:"content"`
			Prefer  string `json:"prefer"`
		}
		if err := decode(r, &req); err != nil {
			s.reply(w, nil, err)
			return
		}
		res, err := detect.Detect([]byte(req.Content), engine.Kind(req.Prefer))
		res.Links = nil
		s.reply(w, res, err)
	})
	mux.HandleFunc("POST /fetch", func(w http.ResponseWriter, r *http.Request) {
		var req struct {
			URL    string `json:"url"`
			Prefer string `json:"prefer"`
		}
		if err := decode(r, &req); err != nil {
			s.reply(w, nil, err)
			return
		}
		res, err := Fetch(r.Context(), req.URL, engine.Kind(req.Prefer))
		s.reply(w, res, err)
	})
	mux.HandleFunc("POST /shutdown", func(w http.ResponseWriter, r *http.Request) {
		st := s.Stop()
		s.reply(w, st, nil)
		s.Shutdown()
	})
	return s.auth(mux)
}

func (s *Server) auth(next http.Handler) http.Handler {
	want := []byte("Bearer " + s.Secret)
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if subtle.ConstantTimeCompare([]byte(r.Header.Get("Authorization")), want) != 1 {
			http.Error(w, `{"error":"unauthorized"}`, http.StatusUnauthorized)
			return
		}
		next.ServeHTTP(w, r)
	})
}

// Shutdown stops the core and releases Done.
func (s *Server) Shutdown() {
	s.Stop()
	s.once.Do(func() { close(s.quit) })
}

// Status returns a copy of the current state.
func (s *Server) Status() Status {
	s.mu.Lock()
	defer s.mu.Unlock()
	st := s.status
	st.Elevated = isElevated()
	st.Version = s.Versions
	return st
}

// Start stops whatever runs and starts req.
func (s *Server) Start(req StartRequest) (Status, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.stopLocked()

	fail := func(err error) (Status, error) {
		s.status = Status{Error: err.Error()}
		return s.statusLocked(), err
	}
	if req.Mode == "" {
		req.Mode = ModePort
	}
	if req.Mode == ModeTUN && !isElevated() {
		return fail(ErrNeedsElevation)
	}
	body := []byte(req.Content)
	det, err := detect.Detect(body, engine.Kind(req.Prefer))
	if err != nil {
		return fail(err)
	}
	if det.Format == detect.ShareLinks {
		return fail(fmt.Errorf("share links (%s) are not supported yet: use the /singbox or /clash subscription",
			strings.Join(det.Protocols, ", ")))
	}
	kind := det.Core
	if req.Core != "" && req.Core != "auto" {
		kind = engine.Kind(req.Core)
		if !kind.Valid() {
			return fail(fmt.Errorf("unknown core %q", req.Core))
		}
	}
	port, err := pickPort(req.Port)
	if err != nil {
		return fail(err)
	}
	apiPort, err := pickPort(-1)
	if err != nil {
		return fail(err)
	}
	controller := fmt.Sprintf("127.0.0.1:%d", apiPort)
	apiSecret := randomHex(16)
	stack := req.TUNStack
	if req.Mode == ModeTUN && stack == "" {
		stack = "gvisor" // opens no sockets: no firewall prompt on Windows
	}
	err = s.mgr.Start(kind, body, engine.Options{
		WorkDir:      filepath.Join(s.WorkDir, string(kind)),
		Controller:   controller,
		Secret:       apiSecret,
		ProxyOnly:    req.Mode != ModeTUN,
		LoopbackOnly: true,
		FindProcess:  true,
		TUNStack:     stack,
		MixedPort:    port,
	})
	if err != nil {
		return fail(err)
	}
	if req.Mode == ModeSystemProxy {
		if err := s.sysprox.Enable(fmt.Sprintf("127.0.0.1:%d", port)); err != nil {
			_ = s.mgr.Stop()
			return fail(fmt.Errorf("system proxy: %w", err))
		}
	}
	now := time.Now()
	det.Links = nil
	s.status = Status{
		Running: true, Core: kind, Mode: req.Mode, Port: port,
		Controller: controller, ControllerSecret: apiSecret, StartedAt: &now, Detect: &det,
	}
	return s.statusLocked(), nil
}

// Stop stops the core (if any) and restores the system proxy.
func (s *Server) Stop() Status {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.stopLocked()
	s.status = Status{}
	return s.statusLocked()
}

func (s *Server) stopLocked() {
	if s.status.Mode == ModeSystemProxy {
		_ = s.sysprox.Disable()
	}
	if s.mgr.Running() != "" {
		_ = s.mgr.Stop()
	}
}

func (s *Server) statusLocked() Status {
	st := s.status
	st.Elevated = isElevated()
	st.Version = s.Versions
	return st
}

// ErrNeedsElevation: TUN was asked for in a process without admin rights.
var ErrNeedsElevation = errors.New("needs-elevation: TUN mode requires administrator rights")

// pickPort returns preferred if free, else 7890 if preferred is 0, else any free port.
func pickPort(preferred int) (int, error) {
	try := func(p int) bool {
		l, err := net.Listen("tcp", fmt.Sprintf("127.0.0.1:%d", p))
		if err != nil {
			return false
		}
		l.Close()
		return true
	}
	if preferred == 0 {
		preferred = 7890
	}
	if preferred > 0 {
		for p := preferred; p < preferred+20; p++ {
			if try(p) {
				return p, nil
			}
		}
	}
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return 0, err
	}
	defer l.Close()
	return l.Addr().(*net.TCPAddr).Port, nil
}

func randomHex(n int) string {
	b := make([]byte, n)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

func decode(r *http.Request, v any) error {
	return json.NewDecoder(io.LimitReader(r.Body, 32<<20)).Decode(v)
}

func (s *Server) reply(w http.ResponseWriter, v any, err error) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	if err != nil {
		code := http.StatusBadRequest
		if errors.Is(err, ErrNeedsElevation) {
			code = http.StatusForbidden
		}
		w.WriteHeader(code)
		out := map[string]any{"error": err.Error()}
		if v != nil {
			out["status"] = v
		}
		_ = json.NewEncoder(w).Encode(out)
		return
	}
	_ = json.NewEncoder(w).Encode(v)
}

// UserAgent identifies the client to subscription servers.
const UserAgent = "solahelm-client/0.1"

// Fetch downloads a subscription and reads the usual headers.
func Fetch(ctx context.Context, url string, prefer engine.Kind) (*FetchResult, error) {
	if !strings.HasPrefix(url, "http://") && !strings.HasPrefix(url, "https://") {
		return nil, errors.New("subscription URL must start with http:// or https://")
	}
	ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", UserAgent)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("server answered %s", resp.Status)
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, 16<<20))
	if err != nil {
		return nil, err
	}
	res := &FetchResult{Content: string(body)}
	parseUserinfo(resp.Header.Get("Subscription-Userinfo"), res)
	res.Title = headerTitle(resp.Header)
	if v, err := strconv.Atoi(strings.TrimSpace(resp.Header.Get("Profile-Update-Interval"))); err == nil {
		res.Interval = v
	}
	det, err := detect.Detect(body, prefer)
	if err != nil {
		res.Error = err.Error()
	} else {
		det.Links = nil
		res.Detect = &det
	}
	return res, nil
}

func parseUserinfo(h string, r *FetchResult) {
	for _, part := range strings.Split(h, ";") {
		k, v, ok := strings.Cut(strings.TrimSpace(part), "=")
		if !ok {
			continue
		}
		n, err := strconv.ParseInt(strings.TrimSpace(v), 10, 64)
		if err != nil {
			continue
		}
		switch strings.ToLower(k) {
		case "upload":
			r.Upload = n
		case "download":
			r.Download = n
		case "total":
			r.Total = n
		case "expire":
			r.Expire = n
		}
	}
}

// headerTitle reads profile-title (plain or "base64:...") or the attachment name.
func headerTitle(h http.Header) string {
	if t := strings.TrimSpace(h.Get("Profile-Title")); t != "" {
		if rest, ok := strings.CutPrefix(t, "base64:"); ok {
			if b, err := base64.StdEncoding.DecodeString(rest); err == nil {
				return string(b)
			}
		}
		return t
	}
	if _, params, err := mime.ParseMediaType(h.Get("Content-Disposition")); err == nil {
		name := params["filename"]
		return strings.TrimSuffix(strings.TrimSuffix(name, ".yaml"), ".json")
	}
	return ""
}

// WatchParent stops everything and exits when the UI process goes away, so an
// elevated core never outlives the app (and never leaves TUN or the system
// proxy behind).
func (s *Server) WatchParent(pid int) {
	if pid <= 0 {
		return
	}
	go func() {
		waitForProcess(pid)
		s.Shutdown()
	}()
}
