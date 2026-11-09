package qr

import (
	"bytes"
	"errors"
	"image"
	"image/color"
	"image/draw"
	"image/jpeg"
	"image/png"
	"testing"

	"github.com/makiuchi-d/gozxing"
	"github.com/makiuchi-d/gozxing/qrcode"
)

const (
	subURL  = "https://panel.example.org/hy/sub/AbCdEfGhIjKlMnOpQrStUvWxYz012345"
	vlessIn = "vless://11111111-2222-3333-4444-555555555555@vps1.example.org:8443?security=reality&sni=www.example.com&fp=chrome&pbk=AbCdEfGhIjKlMnOpQrStUvWxYz0123456789abcdefg&sid=0123abcd&type=tcp&flow=xtls-rprx-vision#DE-VLESS%20Reality"
)

// qrImage renders text as a QR code of size x size pixels.
func qrImage(t *testing.T, text string, size int) *image.Gray {
	t.Helper()
	m, err := qrcode.NewQRCodeWriter().Encode(text, gozxing.BarcodeFormat_QR_CODE, size, size, nil)
	if err != nil {
		t.Fatal(err)
	}
	img := image.NewGray(image.Rect(0, 0, m.GetWidth(), m.GetHeight()))
	for y := 0; y < m.GetHeight(); y++ {
		for x := 0; x < m.GetWidth(); x++ {
			if m.Get(x, y) {
				img.SetGray(x, y, color.Gray{})
			} else {
				img.SetGray(x, y, color.Gray{Y: 255})
			}
		}
	}
	return img
}

func encodePNG(t *testing.T, img image.Image) []byte {
	t.Helper()
	var b bytes.Buffer
	if err := png.Encode(&b, img); err != nil {
		t.Fatal(err)
	}
	return b.Bytes()
}

// A screen-sized picture: dark "window" background with two QR codes, like a
// panel page showing them.
func screenWithTwo(t *testing.T) image.Image {
	t.Helper()
	scr := image.NewRGBA(image.Rect(0, 0, 1920, 1080))
	draw.Draw(scr, scr.Bounds(), image.NewUniform(color.RGBA{30, 32, 36, 255}), image.Point{}, draw.Src)
	draw.Draw(scr, image.Rect(200, 300, 500, 600), image.NewUniform(color.RGBA{60, 64, 70, 255}), image.Point{}, draw.Src)
	q1 := qrImage(t, subURL, 260)
	q2 := qrImage(t, vlessIn, 320)
	draw.Draw(scr, q1.Bounds().Add(image.Pt(900, 250)), q1, image.Point{}, draw.Src)
	draw.Draw(scr, q2.Bounds().Add(image.Pt(1400, 500)), q2, image.Point{}, draw.Src)
	return scr
}

func TestDecodeSingle(t *testing.T) {
	got, err := DecodeBytes(encodePNG(t, qrImage(t, vlessIn, 300)))
	if err != nil || len(got) != 1 || got[0] != vlessIn {
		t.Fatalf("got %q, %v", got, err)
	}
}

func TestDecodeTightCrop(t *testing.T) {
	// A QR cut out without the white margin, small: a quiet border is added.
	m, err := qrcode.NewQRCodeWriter().Encode(subURL, gozxing.BarcodeFormat_QR_CODE, 0, 0,
		map[gozxing.EncodeHintType]interface{}{gozxing.EncodeHintType_MARGIN: 0})
	if err != nil {
		t.Fatal(err)
	}
	img := image.NewGray(image.Rect(0, 0, m.GetWidth()*4, m.GetHeight()*4))
	for y := 0; y < img.Bounds().Dy(); y++ {
		for x := 0; x < img.Bounds().Dx(); x++ {
			if m.Get(x/4, y/4) {
				img.SetGray(x, y, color.Gray{})
			} else {
				img.SetGray(x, y, color.Gray{Y: 255})
			}
		}
	}
	got, err := DecodeBytes(encodePNG(t, img))
	if err != nil || len(got) != 1 || got[0] != subURL {
		t.Fatalf("got %q, %v", got, err)
	}
}

func TestDecodeScreenWithTwo(t *testing.T) {
	got := DecodeImage(screenWithTwo(t))
	if len(got) != 2 {
		t.Fatalf("want both codes, got %q", got)
	}
	has := map[string]bool{got[0]: true, got[1]: true}
	if !has[subURL] || !has[vlessIn] {
		t.Fatalf("got %q", got)
	}
}

func TestDecodeJPEG(t *testing.T) {
	var b bytes.Buffer
	if err := jpeg.Encode(&b, screenWithTwo(t), &jpeg.Options{Quality: 70}); err != nil {
		t.Fatal(err)
	}
	got, err := DecodeBytes(b.Bytes())
	if err != nil || len(got) == 0 {
		t.Fatalf("jpeg: %q, %v", got, err)
	}
}

func TestDecodeErrors(t *testing.T) {
	if _, err := DecodeBytes([]byte("not an image")); err == nil {
		t.Fatal("garbage accepted")
	}
	blank := image.NewGray(image.Rect(0, 0, 800, 600))
	if _, err := DecodeBytes(encodePNG(t, blank)); !errors.Is(err, ErrNotFound) {
		t.Fatalf("blank picture: %v", err)
	}
}
