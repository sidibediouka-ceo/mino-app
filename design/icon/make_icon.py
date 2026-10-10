"""Draws the Mino app icon (the hanger-mascot) and exports every variant.

The hook is the mascot's curl, the hanger is its soft body, the face sits
inside. One geometry, several palettes, so all variants stay identical.

Usage: python3 design/icon/make_icon.py   (needs `pip install cairosvg`)
"""
from pathlib import Path

import cairosvg

ROOT = Path(__file__).resolve().parents[2]
EXPORT = ROOT / "design" / "icon" / "export"
APPICON = ROOT / "Mino" / "Resources" / "Assets.xcassets" / "AppIcon.appiconset"

FOREST = "#1E3A34"
CREAM = "#F5F1EA"
SAGE = "#A7B89C"
DEEP_SAGE = "#6F8A66"
ROSE = "#E9B8B0"

BODY = ("M 512 452 C 630 516, 750 590, 796 648 C 846 712, 820 722, 752 722 "
        "L 272 722 C 204 722, 178 712, 228 648 C 274 590, 394 516, 512 452 Z")
HOOK = "M 438 330 A 74 74 0 1 1 512 404 L 512 452"
LEAVES = ("M 514 204 C 492 150, 452 146, 408 156 C 428 206, 472 220, 514 204 Z "
          "M 518 198 C 542 140, 600 128, 652 136 C 632 196, 582 216, 518 198 Z")


def svg(background, glyph, sprout, face, cheeks):
    fill = f'<rect width="1024" height="1024" fill="{background}"/>' if background else ""
    blush = (f'<circle cx="398" cy="646" r="18" fill="{cheeks}"/>'
             f'<circle cx="626" cy="646" r="18" fill="{cheeks}"/>') if cheeks else ""
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
{fill}
<g transform="translate(0 70)" fill="none" stroke-linecap="round" stroke-linejoin="round">
  <path d="M 512 258 L 516 200" stroke="{sprout}" stroke-width="16"/>
  <path d="{LEAVES}" fill="{sprout}" stroke="none"/>
  <path d="{HOOK}" stroke="{glyph}" stroke-width="46"/>
  <path d="{BODY}" stroke="{glyph}" stroke-width="46"/>
  {blush}
  <path d="M 424 606 Q 450 634 476 606 M 548 606 Q 574 634 600 606" stroke="{face}" stroke-width="26"/>
  <path d="M 488 654 Q 512 676 536 654" stroke="{face}" stroke-width="22"/>
</g>
</svg>"""


VARIANTS = {
    # iOS asset catalog: default (opaque), dark and tinted appearances.
    "AppIcon.png": svg(FOREST, CREAM, SAGE, CREAM, ROSE),
    "AppIcon-Dark.png": svg(None, CREAM, SAGE, CREAM, ROSE),
    "AppIcon-Tinted.png": svg(None, "#FFFFFF", "#B4B4B4", "#FFFFFF", "#8C8C8C"),
    # Brand files for the site, documents and stores.
    "Mino-icon-white.png": svg("#FFFFFF", FOREST, DEEP_SAGE, FOREST, ROSE),
    "Mino-icon-black.png": svg("#000000", CREAM, SAGE, CREAM, ROSE),
    "Mino-icon-transparent-forest.png": svg(None, FOREST, DEEP_SAGE, FOREST, ROSE),
    "Mino-icon-transparent-cream.png": svg(None, CREAM, SAGE, CREAM, ROSE),
}


def main():
    EXPORT.mkdir(parents=True, exist_ok=True)
    for name, source in VARIANTS.items():
        target = APPICON / name if name.startswith("AppIcon") else EXPORT / name
        cairosvg.svg2png(bytestring=source.encode(), write_to=str(target))
    (EXPORT / "Mino-icon.svg").write_text(VARIANTS["AppIcon.png"])


if __name__ == "__main__":
    main()
