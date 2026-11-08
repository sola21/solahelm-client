package daemon

import "golang.org/x/sys/windows"

func isElevated() bool {
	return windows.GetCurrentProcessToken().IsElevated()
}

// waitForProcess blocks until the process with this pid exits.
func waitForProcess(pid int) {
	h, err := windows.OpenProcess(windows.SYNCHRONIZE, false, uint32(pid))
	if err != nil {
		return // already gone (or never existed)
	}
	defer windows.CloseHandle(h)
	_, _ = windows.WaitForSingleObject(h, windows.INFINITE)
}
