"""Draws the Mino app icon (the mascot) and exports every variant.

One geometry, several palettes, so all variants stay identical. The mascot
is drawn in a 180-unit box, then scaled and centred on the 1024 canvas.

Usage: python3 design/icon/make_icon.py   (needs `pip install cairosvg`)
"""
from pathlib import Path

import cairosvg

ROOT = Path(__file__).resolve().parents[2]
EXPORT = ROOT / "design" / "icon" / "export"
APPICON = ROOT / "Mino" / "Resources" / "Assets.xcassets" / "AppIcon.appiconset"

FOREST = "#1E3A34"
CREAM = "#F5F1EA"

# Body: from the bottom left, up to the tuft, then the curl; the right side
# is a separate stroke, leaving the soft gaps of the original drawing.
LEFT = ("M 52 140 C 38 132, 27 117, 27 101 C 27 85, 36 74, 48 66 "
        "C 54 61, 55 50, 57 40 C 60 24, 65 10, 74 10 C 84 10, 90 26, 96 38 "
        "C 100 46, 102 52, 107 50")
# The curl leaves the valley and thins out to a fine tip, like a brush stroke.
CURL = [((107, 50), (112, 48), (116, 38), (124, 35)), ((124, 35), (129, 33), (134, 35), (135, 38))]
CURL_WIDTH = (8, 1.6)
RIGHT = "M 125 66 C 141 75, 152 90, 152 106 C 152 122, 140 136, 122 141"
EYES = "M 58 101 C 60 109, 74 109, 76 101 M 100 101 C 102 109, 116 109, 118 101"
SMILE = "M 79 119 C 82 127, 94 127, 97 119"



def tapered(segments, start_width, end_width, steps=24):
    """Outline of a stroke whose width shrinks along cubic segments."""
    points = []
    for index, (a, b, c, d) in enumerate(segments):
        for step in range(0 if index == 0 else 1, steps + 1):
            t = step / steps
            u = 1 - t
            x = u**3 * a[0] + 3 * u * u * t * b[0] + 3 * u * t * t * c[0] + t**3 * d[0]
            y = u**3 * a[1] + 3 * u * u * t * b[1] + 3 * u * t * t * c[1] + t**3 * d[1]
            dx = 3 * u * u * (b[0] - a[0]) + 6 * u * t * (c[0] - b[0]) + 3 * t * t * (d[0] - c[0])
            dy = 3 * u * u * (b[1] - a[1]) + 6 * u * t * (c[1] - b[1]) + 3 * t * t * (d[1] - c[1])
            points.append((x, y, dx, dy))
    left, right = [], []
    for i, (x, y, dx, dy) in enumerate(points):
        progress = i / (len(points) - 1)
        half = (start_width + (end_width - start_width) * progress ** 0.8) / 2
        length = (dx * dx + dy * dy) ** 0.5 or 1
        nx, ny = -dy / length * half, dx / length * half
        left.append(f"{x + nx:.2f} {y + ny:.2f}")
        right.append(f"{x - nx:.2f} {y - ny:.2f}")
    tip = end_width / 2
    return (f"M {left[0]} L " + " L ".join(left[1:])
            + f" A {tip} {tip} 0 0 0 {right[-1]} L " + " L ".join(reversed(right[:-1])) + " Z")


SCALE = 4.3
CENTER = (89.5, 76)  # visual centre of the drawing, in mascot units


def svg(background, line):
    fill = f'<rect width="1024" height="1024" fill="{background}"/>' if background else ""
    dx, dy = 512 - CENTER[0] * SCALE, 512 - CENTER[1] * SCALE
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
{fill}
<g transform="translate({dx:.1f} {dy:.1f}) scale({SCALE})" fill="none" stroke="{line}" stroke-linecap="round" stroke-linejoin="round">
  <path d="{LEFT}" stroke-width="8"/>
  <path d="{tapered(CURL, *CURL_WIDTH)}" fill="{line}" stroke="none"/>
  <path d="{RIGHT}" stroke-width="8"/>
  <path d="{EYES}" stroke-width="6.5"/>
  <path d="{SMILE}" stroke-width="6.5"/>
</g>
</svg>"""


VARIANTS = {
    # iOS asset catalog: default (opaque), dark and tinted appearances.
    "AppIcon.png": svg(FOREST, CREAM),
    "AppIcon-Dark.png": svg(None, CREAM),
    "AppIcon-Tinted.png": svg(None, "#FFFFFF"),
    # Brand files for the site, documents and stores.
    "Mino-icon-white.png": svg("#FFFFFF", FOREST),
    "Mino-icon-black.png": svg("#000000", CREAM),
    "Mino-icon-transparent-forest.png": svg(None, FOREST),
    "Mino-icon-transparent-cream.png": svg(None, CREAM),
}


def main():
    EXPORT.mkdir(parents=True, exist_ok=True)
    for name, source in VARIANTS.items():
        target = APPICON / name if name.startswith("AppIcon") else EXPORT / name
        cairosvg.svg2png(bytestring=source.encode(), write_to=str(target))
    (EXPORT / "Mino-icon.svg").write_text(VARIANTS["AppIcon.png"])


if __name__ == "__main__":
    main()
