//go:build windows || (linux && !android)

package qr

import (
	"fmt"

	"github.com/kbinani/screenshot"
)

// ScreenSupported says whether Screen can work on this system.
const ScreenSupported = true

// Screen takes a picture of every display and reads the QR codes on them.
func Screen() ([]string, error) {
	n := screenshot.NumActiveDisplays()
	if n == 0 {
		return nil, fmt.Errorf("no displays to capture")
	}
	var out []string
	seen := map[string]bool{}
	var lastErr error
	for i := 0; i < n; i++ {
		img, err := screenshot.CaptureDisplay(i)
		if err != nil {
			lastErr = err
			continue
		}
		for _, t := range DecodeImage(img) {
			if !seen[t] {
				seen[t] = true
				out = append(out, t)
			}
		}
	}
	if len(out) == 0 {
		if lastErr != nil {
			return nil, fmt.Errorf("screen capture: %w", lastErr)
		}
		return nil, ErrNotFound
	}
	return out, nil
}
