# -*- coding: utf-8 -*-
"""Generate the launcher icons: the "film strip".

The idea is a film frame with its perforations, and a cream plate in the middle
with **the symbol cut out of it**, so the accent colour shows through from
behind — a play triangle for Super, a descending arrow for Lite.

Three layers per app, written into `assets/icons/`:
  icon.png             — the complete legacy icon, clipped to a squircle,
                         because Android before 8 shows it as-is with no mask.
  icon_foreground.png  — the adaptive foreground: the whole design at 92% of
                         the file (see [FIT]; the tool adds a 16% inset on top).
  icon_monochrome.png  — Android 13+ themed icons: a white silhouette the
                         system tints. It was missing entirely, which made the
                         icon look out of place whenever the option was on.
The background is a solid colour in pubspec rather than an image, because the
design needs no detail behind it.

**Corners are rounded by a morphological opening** (blur, then threshold):
shrinking the polygon toward its centre distorts scalene triangles, leaving a
bulge at one corner and a cut at another.

Run: python tool/make_icons.py   then  dart run flutter_launcher_icons
"""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

DESIGN = 512          # design units
OUT = 1024            # output size
SS = 3                # supersampling factor
N = OUT * SS
# **Two calculations, not one.** `flutter_launcher_icons` wraps the foreground
# in a 16% inset of its own, which leaves it at 68% of the plate (about 73dp of
# 108) — exactly covering the visible area of 72dp. But the mask is **circular**
# in some launchers, and the farthest point of this design is the corner of the
# top perforation, at a radius of 0.5245 of the drawing's width. It only fits
# inside the circle once the design is scaled to 92% within the file. Without
# that, the perforation edges are clipped and it reads as a defect.
FIT = 0.92

CREAM = (251, 246, 238, 255)
APPS = {
    'metube_lite': {'accent': (47, 109, 116, 255), 'glyph': 'download'},
    'metube_super': {'accent': (194, 94, 46, 255), 'glyph': 'play'},
}

PERF_X = (36, 434)
PERF_Y = (102, 223, 344)
PERF = (42, 66, 15)                      # width, height, corner radius
PANEL = (104, 88, 408, 424, 46)


def u(v):
    return int(round(v * (OUT / DESIGN) * SS))


def rrect(d, box, r, fill):
    d.rounded_rectangle([u(box[0]), u(box[1]), u(box[2]), u(box[3])],
                        radius=u(r), fill=fill)


def round_corners(mask, radius):
    m = mask.filter(ImageFilter.GaussianBlur(u(radius) * 0.62))
    return m.point(lambda v: 255 if v >= 128 else 0)


def squircle(size, n=4.2):
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    c = (size - 1) / 2
    v = (np.abs(x - c) / c) ** n + (np.abs(y - c) / c) ** n
    return Image.fromarray(
        (np.clip((1 - v) * size * 0.35, 0, 1) * 255).astype(np.uint8), 'L')


def glyph_mask(kind):
    m = Image.new('L', (N, N), 0)
    d = ImageDraw.Draw(m)
    if kind == 'play':
        # The bounding box is centred at 264 rather than 256: a triangle's mass
        # sits to the left of its apex, so arithmetic centring makes it look
        # shifted left. This is optical centring.
        d.polygon([(u(184), u(150)), (u(184), u(362)), (u(344), u(256))],
                  fill=255)
    else:
        rrect(d, (228, 118, 284, 262), 28, 255)
        d.polygon([(u(166), u(244)), (u(346), u(244)), (u(256), u(382))],
                  fill=255)
    return round_corners(m, 13)


def artwork_mask(kind):
    """The perforations plus the plate, minus the symbol: the silhouette of
    the whole design."""
    m = Image.new('L', (N, N), 0)
    d = ImageDraw.Draw(m)
    for x in PERF_X:
        for y in PERF_Y:
            rrect(d, (x, y, x + PERF[0], y + PERF[1]), PERF[2], 255)
    rrect(d, PANEL[:4], PANEL[4], 255)
    return Image.fromarray(
        np.minimum(np.array(m), 255 - np.array(glyph_mask(kind))), 'L')


def tinted(mask, color):
    img = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    img.paste(Image.new('RGBA', (N, N), color), (0, 0), mask)
    return img.resize((OUT, OUT), Image.LANCZOS)


def into_safe_zone(layer):
    """The design, scaled inside the guaranteed circle (see [FIT])."""
    side = int(round(OUT * FIT))
    out = Image.new('RGBA', (OUT, OUT), (0, 0, 0, 0))
    out.paste(layer.resize((side, side), Image.LANCZOS),
              ((OUT - side) // 2, (OUT - side) // 2))
    return out


def main():
    for app, cfg in APPS.items():
        mask = artwork_mask(cfg['glyph'])
        art = tinted(mask, CREAM)

        full = Image.new('RGBA', (OUT, OUT), cfg['accent'])
        full.alpha_composite(art)
        full.putalpha(squircle(OUT))
        base = f'apps/{app}/assets/icons'
        full.save(f'{base}/icon.png')
        into_safe_zone(art).save(f'{base}/icon_foreground.png')
        into_safe_zone(tinted(mask, (255, 255, 255, 255))).save(
            f'{base}/icon_monochrome.png')
        print(f'{app}: icon.png · icon_foreground.png · icon_monochrome.png')


if __name__ == '__main__':
    main()
