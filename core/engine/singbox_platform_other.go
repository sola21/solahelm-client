//go:build !android

package engine

// A TUN descriptor from the OS only exists on Android.
func newSingBoxPlatform(int) singBoxPlatform { return nil }
