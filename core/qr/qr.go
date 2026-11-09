// Package qr finds QR codes in pictures and on the screen, for adding a
// subscription or a server from a QR code. Pure Go (gozxing), no cgo.
package qr

import (
	"bytes"
	"errors"
	"image"
	"image/draw"
	_ "image/gif" // registered decoders
	_ "image/jpeg"
	_ "image/png"

	"github.com/makiuchi-d/gozxing"
	multiqr "github.com/makiuchi-d/gozxing/multi/qrcode"
	"github.com/makiuchi-d/gozxing/qrcode"
	_ "golang.org/x/image/webp" // pictures saved from messengers
)

// ErrNotFound means the picture has no readable QR code.
var ErrNotFound = errors.New("no QR code found")

// DecodeImage returns the texts of all QR codes in img, in reading order,
// without duplicates.
func DecodeImage(img image.Image) []string {
	var out []string
	seen := map[string]bool{}
	add := func(rs ...*gozxing.Result) {
		for _, r := range rs {
			if t := r.GetText(); t != "" && !seen[t] {
				seen[t] = true
				out = append(out, t)
			}
		}
	}
	hints := map[gozxing.DecodeHintType]interface{}{gozxing.DecodeHintType_TRY_HARDER: true}
	src := gozxing.NewLuminanceSourceFromImage(img)
	// The hybrid binarizer copes with photos and screens; the global one with
	// flat, high-contrast pictures where the hybrid one sometimes fails.
	for _, bin := range []gozxing.Binarizer{gozxing.NewHybridBinarizer(src), gozxing.NewGlobalHistgramBinarizer(src)} {
		bmp, err := gozxing.NewBinaryBitmap(bin)
		if err != nil {
			continue
		}
		if rs, err := multiqr.NewQRCodeMultiReader().DecodeMultiple(bmp, hints); err == nil {
			add(rs...)
		}
		if len(out) == 0 {
			if r, err := qrcode.NewQRCodeReader().Decode(bmp, hints); err == nil {
				add(r)
			}
		}
		if len(out) > 0 {
			break
		}
	}
	return out
}

// DecodeBytes decodes a PNG, JPEG, GIF or WebP picture and reads its QR codes.
func DecodeBytes(data []byte) ([]string, error) {
	img, _, err := image.Decode(bytes.NewReader(data))
	if err != nil {
		return nil, errors.New("not a picture (PNG, JPEG, GIF or WebP)")
	}
	// Small pictures (a QR cropped tight) read better with a quiet border.
	if b := img.Bounds(); b.Dx() < 400 || b.Dy() < 400 {
		img = withBorder(img, 40)
	}
	texts := DecodeImage(img)
	if len(texts) == 0 {
		return nil, ErrNotFound
	}
	return texts, nil
}

func withBorder(img image.Image, pad int) image.Image {
	b := img.Bounds()
	out := image.NewRGBA(image.Rect(0, 0, b.Dx()+2*pad, b.Dy()+2*pad))
	draw.Draw(out, out.Bounds(), image.White, image.Point{}, draw.Src)
	draw.Draw(out, image.Rect(pad, pad, pad+b.Dx(), pad+b.Dy()), img, b.Min, draw.Over)
	return out
}
