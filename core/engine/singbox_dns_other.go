//go:build !android

package engine

import (
	"context"

	"github.com/sagernet/sing-box/include"
)

func singBoxContext(ctx context.Context) context.Context { return include.Context(ctx) }
