package mobile

import (
	"syscall"

	mdialer "github.com/metacubex/mihomo/component/dialer"

	"github.com/sola21/solahelm-client/core/engine"
)

// setProtector makes every outbound socket of both cores go through
// VpnService.protect: mihomo through its socket hook, sing-box through the
// engine's platform interface.
func setProtector(p Protector) {
	engine.SocketProtector = func(fd int) error {
		if !p.Protect(int32(fd)) {
			return syscall.EPERM
		}
		return nil
	}
	mdialer.DefaultSocketHook = func(network, address string, conn syscall.RawConn) error {
		var protectErr error
		err := conn.Control(func(fd uintptr) {
			if !p.Protect(int32(fd)) {
				protectErr = syscall.EPERM
			}
		})
		if err != nil {
			return err
		}
		return protectErr
	}
}
