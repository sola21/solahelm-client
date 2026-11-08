import sys
from PIL import Image, ImageDraw

S = 1024
def P(pts):  # points in a 0..100 grid
    return [(x * S / 100, y * S / 100) for x, y in pts]

def sail(light, dark, mid):
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.polygon(P([(52, 6), (52, 70), (92, 70)]), fill=light)          # main sail
    d.polygon(P([(46, 22), (46, 70), (14, 70)]), fill=mid)           # jib
    d.polygon(P([(8, 76), (94, 76), (80, 94), (22, 94)]), fill=dark) # hull
    return im

def zigzag(light, dark, mid):
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.polygon(P([(60, 4), (88, 4), (40, 52), (12, 52)]), fill=light)   # upper bar
    d.polygon(P([(12, 52), (40, 52), (64, 76), (36, 76)]), fill=dark)  # turn
    d.polygon(P([(36, 76), (64, 76), (88, 52), (88, 96), (60, 96)]), fill=mid)  # lower bar
    return im

def chevrons(light, dark, mid):
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.polygon(P([(8, 10), (34, 10), (64, 50), (34, 90), (8, 90), (38, 50)]), fill=light)
    d.polygon(P([(40, 10), (66, 10), (96, 50), (66, 90), (40, 90), (70, 50)]), fill=dark)
    d.polygon(P([(52, 26), (66, 10), (96, 50), (84, 50)]), fill=mid)   # facet on the front chevron
    return im

BLUE = ((0x4F, 0xC3, 0xF7, 255), (0x01, 0x57, 0x9B, 255), (0x02, 0x88, 0xD1, 255))
GREEN = ((0x81, 0xC7, 0x84, 255), (0x1B, 0x5E, 0x20, 255), (0x38, 0x8E, 0x3C, 255))
DESIGNS = {"sail": sail, "zigzag": zigzag, "chevrons": chevrons}

def preview(out):
    W = 3 * 330
    pv = Image.new("RGBA", (W, 420), (245, 245, 245, 255))
    dk = Image.new("RGBA", (W, 120), (32, 32, 32, 255)); pv.paste(dk, (0, 300))
    for i, (name, f) in enumerate(DESIGNS.items()):
        x0 = i * 330 + 15
        for j, pal in enumerate((BLUE, GREEN)):
            big = f(*pal).resize((140, 140), Image.LANCZOS)
            pv.paste(big, (x0 + j * 155, 20), big)
            x = x0 + j * 155
            for s in (16, 24, 32, 48):
                sm = f(*pal).resize((s, s), Image.LANCZOS)
                pv.paste(sm, (x, 190), sm)
                pv.paste(sm, (x, 330), sm)
                x += s + 8
        ImageDraw.Draw(pv).text((x0, 270), f"{i+1}. {name}", fill=(40, 40, 40, 255))
    pv.save(out)

def apply(name, app_dir):
    f = DESIGNS[name]
    sizes = [(s, s) for s in (16, 20, 24, 32, 40, 48, 64, 128, 256)]
    def ico(pal, path):
        imgs = [f(*pal).resize(sz, Image.LANCZOS) for sz in sizes]
        imgs[-1].save(path, format="ICO", sizes=sizes, append_images=imgs[:-1])
    ico(BLUE, f"{app_dir}/windows/runner/resources/app_icon.ico")
    ico(BLUE, f"{app_dir}/assets/tray_off.ico")
    ico(GREEN, f"{app_dir}/assets/tray_on.ico")
    f(*BLUE).resize((256, 256), Image.LANCZOS).save(f"{app_dir}/assets/icon.png")
    f(*GREEN).resize((256, 256), Image.LANCZOS).save(f"{app_dir}/assets/icon_on.png")

if sys.argv[1] == "preview":
    preview(sys.argv[2])
else:
    apply(sys.argv[2], sys.argv[3])
