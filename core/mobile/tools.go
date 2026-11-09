//go:build tools

package mobile

// gomobile bind needs golang.org/x/mobile in go.mod; this keeps
// `go mod tidy` from dropping it.
import _ "golang.org/x/mobile/bind"
