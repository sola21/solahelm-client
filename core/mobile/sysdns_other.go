//go:build !(android && cmfa)

package mobile

// SetSystemDNS is a no-op outside the Android (cmfa) build; mihomo reads the
// system resolvers itself there.
func SetSystemDNS(servers string) {}
