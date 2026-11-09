//go:build !(windows || (linux && !android))

package qr

import "errors"

// ScreenSupported says whether Screen can work on this system.
const ScreenSupported = false

// Screen is not available here (Android uses the camera instead).
func Screen() ([]string, error) {
	return nil, errors.New("screen capture is not supported on this system")
}
