"""Erzeugt das App-Icon (1024 px) neu: python3 tools/make_icon.py

Seite im Scan-Rahmen; die obere Ecke rollt sich ein wie ein junges Farnblatt.
Sola-Iconstil: weiße, schlanke Linie auf der Leitfarbe der App; genau eine Linie
läuft in eine Farnspirale (Fiddlehead) aus. Braucht Pillow.
"""
import math
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTS = [
    os.path.join(ROOT, 'SolaScanner/Assets.xcassets/AppIcon.appiconset/icon-1024.png'),
]
BRAND = '#0B8A7E'

SS = 4
SW = 30  # Strichstärke auf der 1024er-Fläche
INK = '#FFFFFF'


class Pen:
    """Sammelt Linienzüge; Kurven werden beim Zeichnen in Punkte aufgelöst."""

    def __init__(self):
        self.lines = []

    def move(self, x, y):
        self.lines.append([(x, y)])
        return self

    def line(self, *pts):
        for i in range(0, len(pts), 2):
            self.lines[-1].append((pts[i], pts[i + 1]))
        return self

    def curve(self, x1, y1, x2, y2, x, y, steps=40):
        (x0, y0) = self.lines[-1][-1]
        for i in range(1, steps + 1):
            t = i / steps
            a, b, c, d = (1 - t) ** 3, 3 * (1 - t) ** 2 * t, 3 * (1 - t) * t ** 2, t ** 3
            self.lines[-1].append((a * x0 + b * x1 + c * x2 + d * x, a * y0 + b * y1 + c * y2 + d * y))
        return self

    def quad(self, cx, cy, x, y, steps=20):
        (x0, y0) = self.lines[-1][-1]
        for i in range(1, steps + 1):
            t = i / steps
            a, b, c = (1 - t) ** 2, 2 * (1 - t) * t, t ** 2
            self.lines[-1].append((a * x0 + b * cx + c * x, a * y0 + b * cy + c * y))
        return self

    def close(self):
        self.lines[-1].append(self.lines[-1][0])
        return self

    def spiral(self, x, y, heading, r, turns=3, left=False, steps=60):
        """Farnspirale ab (x, y); heading in Grad, 0 = nach oben, im Uhrzeigersinn."""
        h = math.radians(heading)
        sx = -1 if left else 1
        place = lambda px, py: (x + sx * px * math.cos(h) - py * math.sin(h),
                                y + sx * px * math.sin(h) + py * math.cos(h))
        pts, start = [place(0, 0)], 0.0
        for i, f in enumerate((1, 0.64, 0.33, 0.12)[:turns]):
            rr = r * f
            cx, a0 = (start + rr, math.pi) if i % 2 == 0 else (start - rr, 0.0)
            for k in range(1, steps + 1):
                a = a0 + math.pi * k / steps
                pts.append(place(cx + rr * math.cos(a), rr * math.sin(a)))
            start = cx + rr * math.cos(a0 + math.pi)
        self.lines.append(pts)
        return self


def heading(dx, dy):
    return math.degrees(math.atan2(dx, -dy))


def render(motif, background, out, size=1024):
    big = size * SS
    k = big / 1024.0
    w = SW * k
    im = Image.new('RGB', (big, big), background)  # iOS rundet selbst ab, kein Alpha erlaubt
    d = ImageDraw.Draw(im)
    pen = Pen()
    motif(pen)
    for pts in pen.lines:
        pts = [(x * k, y * k) for x, y in pts]
        # Segment für Segment mit runden Gelenken; joint='curve' franst bei dicken Linien aus
        for a, b in zip(pts, pts[1:]):
            d.line((a, b), fill=INK, width=round(w))
        for x, y in pts:
            d.ellipse((x - w / 2, y - w / 2, x + w / 2, y + w / 2), fill=INK)
    im.resize((size, size), Image.LANCZOS).save(out, optimize=True)
    print('Icon geschrieben nach', out)


def motif(p):
    p.move(556, 270).line(370, 270).quad(350, 270, 350, 290).line(350, 734).quad(350, 754, 370, 754)
    p.line(654, 754).quad(674, 754, 674, 734).line(674, 420).curve(674, 330, 650, 282, 556, 270)
    p.spiral(556, 270, -90, r=66, turns=2, left=True)
    for y, x1 in ((470, 612), (544, 612), (618, 540)):
        p.move(412, y).line(x1, y)
    a, b, c = 196, 828, 96  # Scan-Rahmen
    p.move(a, a + c).line(a, a, a + c, a)
    p.move(b - c, a).line(b, a, b, a + c)
    p.move(a, b - c).line(a, b, a + c, b)
    p.move(b - c, b).line(b, b, b, b - c)


if __name__ == '__main__':
    for out in OUTS:
        render(motif, BRAND, out)
