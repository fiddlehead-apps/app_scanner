"""Erzeugt das App-Icon (1024 px) neu: python3 tools/make_icon.py

Blatt Papier im gelben Sucherrahmen mit kleinem Funkeln auf Petrol, im flachen Stil der
anderen Sola-Icons. Braucht Pillow.
"""
import math
import os

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   'SolaScanner', 'Assets.xcassets', 'AppIcon.appiconset', 'icon-1024.png')
SS = 4

BRAND = '#0B8A7E'
PAGE = '#FFFFFF'
FOLD = '#C9EDE7'
LINE = '#B5DDD6'
FRAME = '#FFC857'


def rrect(x0, y0, x1, y1, r, steps=12):
    pts = []
    for cx, cy, start in ((x1 - r, y0 + r, -90), (x1 - r, y1 - r, 0), (x0 + r, y1 - r, 90), (x0 + r, y0 + r, 180)):
        for i in range(steps + 1):
            a = math.radians(start + 90 * i / steps)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def page():
    # Sheet with the top right corner folded over.
    x0, y0, x1, y1, fold = 158, 112, 354, 382, 56
    sheet = [(x0, y0), (x1 - fold, y0), (x1, y0 + fold), (x1, y1), (x0, y1)]
    corner = [(x1 - fold, y0), (x1 - fold, y0 + fold), (x1, y0 + fold)]
    return sheet, corner


def lines():
    out = []
    for i, (y, x1) in enumerate(((190, 270), (226, 322), (258, 322), (290, 300), (322, 250))):
        out.append(rrect(186, y - 8, x1, y + 8, 8, 4))
    return out


def brackets(x0, y0, x1, y1, length, width):
    # Four corner brackets of a camera viewfinder.
    out = []
    for cx, cy, sx, sy in ((x0, y0, 1, 1), (x1, y0, -1, 1), (x0, y1, 1, -1), (x1, y1, -1, -1)):
        horizontal = (cx, cy, cx + sx * length, cy + sy * width)
        vertical = (cx, cy, cx + sx * width, cy + sy * length)
        for ax, ay, bx, by in (horizontal, vertical):
            out.append(rrect(min(ax, bx), min(ay, by), max(ax, bx), max(ay, by), width / 2, 4))
    return out


def sparkle(cx, cy, r):
    # Four-pointed star whose sides curve inwards towards the centre.
    pts = []
    tips = [(cx + r * math.cos(a), cy + r * math.sin(a)) for a in (math.pi * i / 2 for i in range(4))]
    for i in range(4):
        a, b = tips[i], tips[(i + 1) % 4]
        control = (cx + (a[0] + b[0] - 2 * cx) * 0.12, cy + (a[1] + b[1] - 2 * cy) * 0.12)
        pts += [((1 - t) ** 2 * a[0] + 2 * (1 - t) * t * control[0] + t ** 2 * b[0],
                 (1 - t) ** 2 * a[1] + 2 * (1 - t) * t * control[1] + t ** 2 * b[1])
                for t in (j / 16 for j in range(16))]
    return pts


if __name__ == '__main__':
    size = 1024
    big = size * SS
    k = big / 512.0
    place = lambda pts: [(x * k, y * k) for x, y in pts]
    im = Image.new('RGB', (big, big), BRAND)  # iOS rundet selbst ab, kein Alpha erlaubt
    d = ImageDraw.Draw(im)

    for part in brackets(108, 72, 404, 422, 74, 22):
        d.polygon(place(part), fill=FRAME)
    sheet, corner = page()
    d.polygon(place(sheet), fill=PAGE)
    d.polygon(place(corner), fill=FOLD)
    for line in lines():
        d.polygon(place(line), fill=LINE)
    d.polygon(place(sparkle(322, 326, 50)), fill=FRAME)

    im.resize((size, size), Image.LANCZOS).save(OUT, optimize=True)
    print('Icon geschrieben nach', OUT)
