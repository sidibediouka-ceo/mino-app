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
        "C 100 46, 102 52, 107 50 C 112 48, 116 38, 124 35 C 129 33, 134 35, 135 38")
RIGHT = "M 125 66 C 141 75, 152 90, 152 106 C 152 122, 140 136, 122 141"
EYES = "M 58 101 C 60 109, 74 109, 76 101 M 100 101 C 102 109, 116 109, 118 101"
SMILE = "M 79 119 C 82 127, 94 127, 97 119"

SCALE = 4.3
CENTER = (89.5, 76)  # visual centre of the drawing, in mascot units


def svg(background, line):
    fill = f'<rect width="1024" height="1024" fill="{background}"/>' if background else ""
    dx, dy = 512 - CENTER[0] * SCALE, 512 - CENTER[1] * SCALE
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
{fill}
<g transform="translate({dx:.1f} {dy:.1f}) scale({SCALE})" fill="none" stroke="{line}" stroke-linecap="round" stroke-linejoin="round">
  <path d="{LEFT}" stroke-width="8"/>
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
