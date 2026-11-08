//go:build !windows

package daemon

import "errors"

type noSystemProxy struct{}

func newSystemProxy() systemProxy { return noSystemProxy{} }

func (noSystemProxy) Enable(string) error {
	return errors.New("system proxy mode is not implemented on this OS yet")
}

func (noSystemProxy) Disable() error { return nil }
