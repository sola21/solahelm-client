package main

import (
	"errors"
	"flag"
	"fmt"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	mihomoC "github.com/metacubex/mihomo/constant"
	singboxC "github.com/sagernet/sing-box/constant"

	"github.com/sola21/solahelm-client/core/daemon"
)

// cmdServe runs the control API for the UI.
//
//	corectl serve -secret-file F -ready-file R [-listen 127.0.0.1:0] [-parent PID] [-workdir D]
//
// The secret is read from a file (and the file deleted) rather than taken from
// the command line, which other local users can see. Once listening, the
// address is written to the ready file so the UI can find it, which also works
// when the UI started us elevated through UAC.
func cmdServe(args []string) {
	fs := flag.NewFlagSet("serve", flag.ExitOnError)
	listen := fs.String("listen", "127.0.0.1:0", "control API address (loopback only)")
	secretFile := fs.String("secret-file", "", "file with the API secret; deleted after reading")
	readyFile := fs.String("ready-file", "", "write the listen address here once ready")
	parent := fs.Int("parent", 0, "exit when this process exits")
	workdir := fs.String("workdir", defaultWorkDir(), "state directory for the cores")
	fs.Parse(args)

	secret := os.Getenv("SOLAHELM_SECRET")
	if *secretFile != "" {
		b, err := os.ReadFile(*secretFile)
		if err != nil {
			fatal(err)
		}
		_ = os.Remove(*secretFile)
		secret = strings.TrimSpace(string(b))
	}
	if len(secret) < 16 {
		fatal(errors.New("serve: need a secret of at least 16 characters (-secret-file or SOLAHELM_SECRET)"))
	}
	host, _, err := net.SplitHostPort(*listen)
	if err != nil || (host != "127.0.0.1" && host != "::1" && host != "localhost") {
		fatal(fmt.Errorf("serve: -listen must be a loopback address, got %q", *listen))
	}

	srv := daemon.New(secret, *workdir, map[string]string{"sing-box": singboxC.Version, "mihomo": mihomoC.Version})
	srv.WatchParent(*parent)

	l, err := net.Listen("tcp", *listen)
	if err != nil {
		fatal(err)
	}
	httpSrv := &http.Server{Handler: srv.Handler(), ReadHeaderTimeout: 10 * time.Second}
	go func() {
		if err := httpSrv.Serve(l); err != nil && !errors.Is(err, http.ErrServerClosed) {
			fmt.Fprintln(os.Stderr, "serve:", err)
			srv.Shutdown()
		}
	}()
	addr := l.Addr().String()
	if *readyFile != "" {
		if err := os.WriteFile(*readyFile, []byte(addr), 0o600); err != nil {
			fatal(err)
		}
	}
	fmt.Fprintf(os.Stderr, "serve: control API at http://%s (elevated: %v)\n", addr, srv.Status().Elevated)

	sig := make(chan os.Signal, 1)
	signal.Notify(sig, os.Interrupt, syscall.SIGTERM)
	select {
	case <-sig:
		srv.Shutdown()
	case <-srv.Done():
	}
	_ = httpSrv.Close()
	fmt.Fprintln(os.Stderr, "serve: stopped")
}
