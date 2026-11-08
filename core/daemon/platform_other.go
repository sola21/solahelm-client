//go:build !windows

package daemon

import (
	"os"
	"syscall"
	"time"
)

func isElevated() bool { return os.Geteuid() == 0 }

// waitForProcess blocks until the process with this pid exits.
func waitForProcess(pid int) {
	for {
		if err := syscall.Kill(pid, 0); err != nil && err != syscall.EPERM {
			return
		}
		time.Sleep(2 * time.Second)
	}
}
