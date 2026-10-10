"""Draws the flat-lay clothes used by the demo scenarios (Debug builds only).

Each garment is a vector illustration on a transparent background, like the
background-free photos Mino keeps. One drawing per category, recoloured.

Usage: python3 design/demo/make_demo_garments.py   (needs `pip install cairosvg pillow`)
"""
import io
from pathlib import Path

import cairosvg
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "Mino" / "DemoContent"

PALETTE = {
    "white": "#F7F5F0", "grey": "#B9BCC2", "black": "#3A3B40", "beige": "#E2D3B8",
    "brown": "#8B6243", "navy": "#2F4466", "denim": "#5F82AB", "red": "#D6574F",
    "pink": "#F2B8C2", "orange": "#EE9A57", "yellow": "#F4CF61", "green": "#86AE8A",
    "blue": "#86B3DB", "purple": "#B39DD4",
}


def shade(hex_color, factor):
    r, g, b = (int(hex_color[i:i + 2], 16) for i in (1, 3, 5))
    mix = (lambda c: int(c * factor)) if factor < 1 else (lambda c: int(c + (255 - c) * (factor - 1)))
    return "#%02X%02X%02X" % tuple(max(0, min(255, mix(c))) for c in (r, g, b))


def stripes(pid, base, accent, width=26):
    return (f'<pattern id="{pid}" width="{width * 2}" height="{width * 2}" patternUnits="userSpaceOnUse">'
            f'<rect width="{width * 2}" height="{width * 2}" fill="{base}"/>'
            f'<rect y="{width}" width="{width * 2}" height="{width}" fill="{accent}"/></pattern>')


def flowers(pid, base, accent):
    return (f'<pattern id="{pid}" width="70" height="70" patternUnits="userSpaceOnUse">'
            f'<rect width="70" height="70" fill="{base}"/>'
            f'<g fill="{accent}"><circle cx="18" cy="18" r="6"/><circle cx="27" cy="18" r="6"/>'
            f'<circle cx="22" cy="10" r="6"/><circle cx="22" cy="26" r="6"/></g>'
            f'<circle cx="22" cy="18" r="4" fill="#F4CF61"/>'
            f'<circle cx="55" cy="52" r="5" fill="{accent}" opacity="0.6"/></pattern>')


def stars(pid, base, accent):
    return (f'<pattern id="{pid}" width="80" height="80" patternUnits="userSpaceOnUse">'
            f'<rect width="80" height="80" fill="{base}"/>'
            f'<path d="M20 8 L24 18 L35 18 L26 24 L29 35 L20 28 L11 35 L14 24 L5 18 L16 18 Z" fill="{accent}"/>'
            f'<circle cx="60" cy="58" r="4" fill="{accent}"/></pattern>')


def fill_for(spec, defs):
    color = PALETTE[spec["color"]]
    pattern = spec.get("pattern")
    if not pattern:
        return color
    accent = PALETTE[spec.get("accent", "white")]
    pid = "p" + pattern
    defs.append({"stripes": stripes, "flowers": flowers, "stars": stars}[pattern](pid, color, accent))
    return f"url(#{pid})"


def outline(color):
    return f'stroke="{shade(color, 0.72)}" stroke-width="5" stroke-linejoin="round"'


TOP = "M200 110 Q300 150 400 110 L500 160 L470 250 L420 230 L420 500 L180 500 L180 230 L130 250 L100 160 Z"
LONG = ("M200 110 Q300 150 400 110 L470 150 L540 420 L480 440 L420 250 L420 500 L180 500 "
        "L180 250 L120 440 L60 420 L130 150 Z")


def garment(spec):
    category, base = spec["category"], PALETTE[spec["color"]]
    defs, body = [], []
    fill = fill_for(spec, defs)
    line, dark, light = outline(base), shade(base, 0.8), shade(base, 1.35)
    seam = f'fill="none" stroke="{dark}" stroke-width="4" stroke-dasharray="10 8" stroke-linecap="round"'

    if category in ("tshirt", "longSleeve", "turtleneck", "sweater", "cardigan"):
        shape = TOP if category == "tshirt" else LONG
        body.append(f'<path d="{shape}" fill="{fill}" {line}/>')
        if category == "turtleneck":
            body.append(f'<path d="M230 70 L370 70 L380 128 Q300 150 220 128 Z" fill="{fill}" {line}/>')
            body += [f'<path d="M{x} 78 L{x} 130" stroke="{dark}" stroke-width="3"/>' for x in range(250, 360, 18)]
        else:
            body.append(f'<path d="M232 118 Q300 175 368 118" fill="none" stroke="{dark}" stroke-width="7"/>')
        if category in ("sweater", "cardigan"):
            body.append(f'<rect x="180" y="462" width="240" height="38" fill="{dark}" opacity="0.35"/>')
            body.append(f'<path d="M120 440 L60 420 L70 390 L130 410 Z M480 440 L540 420 L530 390 L470 410 Z" fill="{dark}" opacity="0.35"/>')
            body += [f'<path d="M{x} 200 Q{x + 10} 330 {x} 455" fill="none" stroke="{dark}" stroke-width="3" opacity="0.45"/>'
                     for x in range(215, 400, 34)]
        if category == "cardigan":
            body.append(f'<path d="M300 140 L300 500" stroke="{dark}" stroke-width="6"/>')
            body += [f'<circle cx="318" cy="{y}" r="9" fill="{light}" stroke="{dark}" stroke-width="3"/>' for y in range(200, 480, 65)]
        if spec.get("print"):
            body.append(f'<path d="M300 300 m-40 0 a40 40 0 1 0 80 0 a40 40 0 1 0 -80 0" fill="{light}"/>'
                        f'<path d="M282 300 l14 14 l26 -30" fill="none" stroke="{dark}" stroke-width="7" stroke-linecap="round"/>')
    elif category == "dress":
        body.append(f'<path d="M215 100 Q300 140 385 100 L440 140 L410 200 L385 185 L380 280 L480 520 Q300 560 120 520 '
                    f'L220 280 L215 185 L190 200 L160 140 Z" fill="{fill}" {line}/>')
        body.append(f'<path d="M232 108 Q300 160 368 108" fill="none" stroke="{dark}" stroke-width="6"/>')
        body.append(f'<path d="M218 282 Q300 300 382 282" fill="none" stroke="{dark}" stroke-width="10"/>')
    elif category == "playsuit":
        body.append(f'<path d="M210 70 Q300 105 390 70 L470 110 L445 180 L405 165 L405 300 L195 300 L195 165 L155 180 L130 110 Z" fill="{fill}" {line}/>')
        body.append(f'<path d="M232 78 Q300 120 368 78" fill="none" stroke="{dark}" stroke-width="6"/>')
        body.append(f'<path d="M190 340 L410 340 L430 530 L315 530 L300 430 L285 530 L170 530 Z" fill="{fill}" {line}/>')
        body.append(f'<rect x="190" y="340" width="220" height="24" fill="{dark}" opacity="0.4"/>')
    elif category in ("pants", "overalls", "pajamaPants"):
        top = 200 if category == "overalls" else 70
        body.append(f'<path d="M190 {top} L410 {top} L450 540 L330 540 L300 {top + 140} L270 540 L150 540 Z" fill="{fill}" {line}/>')
        body.append(f'<rect x="190" y="{top}" width="220" height="30" fill="{dark}" opacity="0.4"/>')
        body.append(f'<path d="M300 {top + 30} L300 {top + 130}" {seam}/>')
        if spec["color"] == "denim":
            body.append(f'<path d="M205 {top + 40} Q235 {top + 75} 265 {top + 40} M335 {top + 40} Q365 {top + 75} 395 {top + 40}" {seam}/>')
            body.append(f'<path d="M160 520 L270 520 M330 520 L440 520" {seam}/>')
        if category == "overalls":
            body.append(f'<path d="M215 60 L385 60 L395 215 L205 215 Z" fill="{fill}" {line}/>')
            body.append(f'<rect x="255" y="95" width="90" height="70" rx="8" fill="none" stroke="{dark}" stroke-width="4" stroke-dasharray="9 7"/>')
            body.append(f'<path d="M222 62 L170 10 M378 62 L430 10" stroke="{base}" stroke-width="26" stroke-linecap="round"/>')
            body += [f'<circle cx="{x}" cy="78" r="10" fill="#E2C46A" stroke="{dark}" stroke-width="3"/>' for x in (232, 368)]
    elif category == "shorts":
        body.append(f'<path d="M210 140 L390 140 L470 470 Q300 510 130 470 Z" fill="{fill}" {line}/>')
        body.append(f'<rect x="210" y="140" width="180" height="34" fill="{dark}" opacity="0.4"/>')
        body += [f'<path d="M{x} 180 L{x + (x - 300) * 0.7:.0f} 480" stroke="{dark}" stroke-width="3" opacity="0.4"/>' for x in (240, 270, 330, 360)]
    elif category == "tights":
        body.append(f'<path d="M215 60 L385 60 L380 300 L350 520 Q350 560 400 565 L400 590 L320 590 L300 330 '
                    f'L280 590 L200 590 L200 565 Q250 560 250 520 L220 300 Z" fill="{fill}" {line}/>')
        body.append(f'<rect x="215" y="60" width="170" height="26" fill="{dark}" opacity="0.4"/>')
    elif category in ("lightJacket", "coat", "raincoat"):
        bottom = 560 if category == "coat" else 500
        body.append(f'<path d="M200 110 Q300 140 400 110 L470 150 L540 430 L480 450 L425 260 L425 {bottom} L175 {bottom} '
                    f'L175 260 L120 450 L60 430 L130 150 Z" fill="{fill}" {line}/>')
        if category == "raincoat":
            body.append(f'<path d="M210 120 Q200 30 300 25 Q400 30 390 120 Q300 150 210 120 Z" fill="{fill}" {line}/>')
            body += [f'<rect x="285" y="{y}" width="30" height="12" rx="6" fill="{dark}"/>' for y in range(190, 480, 70)]
        else:
            body.append(f'<path d="M240 115 L300 210 L360 115" fill="{dark}" opacity="0.45"/>')
        body.append(f'<path d="M300 150 L300 {bottom}" stroke="{dark}" stroke-width="6"/>')
        if category == "coat":
            body += [f'<circle cx="{x}" cy="{y}" r="11" fill="{dark}"/>' for x in (270, 330) for y in (260, 340, 420)]
        body.append(f'<path d="M195 {bottom - 120} L265 {bottom - 120} M335 {bottom - 120} L405 {bottom - 120}" stroke="{dark}" stroke-width="6" stroke-linecap="round"/>')
    elif category == "sneakers":
        body.append(f'<path d="M90 380 Q100 250 200 230 L300 220 Q340 300 430 320 Q520 340 520 400 L520 430 L90 430 Z" fill="{fill}" {line}/>')
        body.append('<path d="M80 420 L530 420 Q535 470 500 470 L100 470 Q75 470 80 420 Z" fill="#FBFAF7" stroke="#C9C4BA" stroke-width="5"/>')
        body += [f'<path d="M{x} {y} l40 18" stroke="{light}" stroke-width="9" stroke-linecap="round"/>' for x, y in ((230, 250), (255, 280), (280, 308))]
        body.append(f'<path d="M120 330 Q200 330 260 370" fill="none" stroke="{dark}" stroke-width="5" opacity="0.6"/>')
    elif category == "boots":
        body.append(f'<path d="M170 90 L330 90 L335 330 Q440 340 500 390 Q520 430 500 450 L160 450 Z" fill="{fill}" {line}/>')
        body.append('<path d="M150 440 L510 440 Q515 485 485 485 L160 485 Q145 485 150 440 Z" fill="#4A3A30"/>')
        body.append(f'<rect x="165" y="90" width="170" height="40" fill="{dark}" opacity="0.4"/>')
    elif category == "coldAccessory":
        body.append(f'<path d="M130 400 Q120 160 300 150 Q480 160 470 400 Z" fill="{fill}" {line}/>')
        body.append(f'<rect x="115" y="380" width="370" height="90" rx="20" fill="{dark}" {line}/>')
        body += [f'<path d="M{x} 390 L{x} 460" stroke="{shade(base, 0.6)}" stroke-width="5"/>' for x in range(150, 470, 30)]
        body.append(f'<circle cx="300" cy="135" r="55" fill="{light}" stroke="{dark}" stroke-width="5"/>')
    else:
        raise ValueError(category)

    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="600" height="600" viewBox="0 0 600 600">'
            f'<defs>{"".join(defs)}</defs>{"".join(body)}</svg>')


# name: (category, color, extras). Names are referenced by DemoScenarios.swift.
GARMENTS = {
    "tshirt-white": {"category": "tshirt", "color": "white", "print": True},
    "tshirt-pink": {"category": "tshirt", "color": "pink"},
    "tshirt-yellow": {"category": "tshirt", "color": "yellow"},
    "tshirt-stripes": {"category": "tshirt", "color": "navy", "pattern": "stripes", "accent": "white"},
    "tshirt-blue": {"category": "tshirt", "color": "blue", "print": True},
    "tshirt-green": {"category": "tshirt", "color": "green"},
    "tshirt-purple": {"category": "tshirt", "color": "purple"},
    "longsleeve-stripes": {"category": "longSleeve", "color": "red", "pattern": "stripes", "accent": "white"},
    "longsleeve-white": {"category": "longSleeve", "color": "white"},
    "longsleeve-green": {"category": "longSleeve", "color": "green"},
    "longsleeve-red": {"category": "longSleeve", "color": "red"},
    "turtleneck-beige": {"category": "turtleneck", "color": "beige"},
    "sweater-navy": {"category": "sweater", "color": "navy"},
    "sweater-red": {"category": "sweater", "color": "red"},
    "sweater-grey": {"category": "sweater", "color": "grey"},
    "sweater-yellow": {"category": "sweater", "color": "yellow"},
    "cardigan-pink": {"category": "cardigan", "color": "pink"},
    "cardigan-green": {"category": "cardigan", "color": "green"},
    "dress-flowers": {"category": "dress", "color": "navy", "pattern": "flowers", "accent": "pink"},
    "dress-yellow": {"category": "dress", "color": "yellow"},
    "playsuit-green": {"category": "playsuit", "color": "green"},
    "pants-denim": {"category": "pants", "color": "denim"},
    "pants-beige": {"category": "pants", "color": "beige"},
    "pants-black": {"category": "pants", "color": "black"},
    "pants-navy": {"category": "pants", "color": "navy"},
    "pants-grey": {"category": "pants", "color": "grey"},
    "overalls-denim": {"category": "overalls", "color": "denim"},
    "skirt-pink": {"category": "shorts", "color": "pink"},
    "tights-grey": {"category": "tights", "color": "grey"},
    "tights-pink": {"category": "tights", "color": "pink"},
    "jacket-denim": {"category": "lightJacket", "color": "denim"},
    "coat-beige": {"category": "coat", "color": "beige"},
    "coat-navy": {"category": "coat", "color": "navy"},
    "raincoat-yellow": {"category": "raincoat", "color": "yellow"},
    "raincoat-red": {"category": "raincoat", "color": "red"},
    "sneakers-white": {"category": "sneakers", "color": "white"},
    "sneakers-blue": {"category": "sneakers", "color": "blue"},
    "boots-brown": {"category": "boots", "color": "brown"},
    "beanie-red": {"category": "coldAccessory", "color": "red"},
    "pajamas-stars": {"category": "pants", "color": "purple", "pattern": "stars", "accent": "yellow"},
}


def render(spec, size=600):
    return Image.open(io.BytesIO(cairosvg.svg2png(bytestring=garment(spec).encode(), output_width=size))).convert("RGBA")


def outfit_photo(names):
    """A flat-lay of an outfit on linen, standing in for a parent's photo of the day."""
    canvas = Image.new("RGB", (1200, 1500), "#EFE6D8")
    grain = Image.effect_noise((1200, 1500), 18).convert("L")
    canvas = Image.blend(canvas, Image.merge("RGB", (grain, grain, grain)), 0.06)
    spots = [(130, 120, 520), (620, 160, 470), (150, 640, 560), (690, 700, 380), (650, 1080, 380), (200, 1120, 380)]
    for name, (x, y, size) in zip(names, spots):
        image = render(GARMENTS[name], size)
        shadow = Image.new("RGBA", image.size, (60, 40, 20, 0))
        shadow.putalpha(image.getchannel("A").point(lambda a: a // 5))
        canvas.paste(shadow, (x + 10, y + 14), shadow)
        canvas.paste(image, (x, y), image)
    return canvas


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, spec in GARMENTS.items():
        render(spec, 600).save(OUT / f"DemoGarment-{name}.png", optimize=True)
    outfit_photo(["longsleeve-stripes", "cardigan-pink", "skirt-pink", "tights-grey", "sneakers-white", "beanie-red"]) \
        .save(OUT / "DemoOutfitPhoto.jpg", quality=85)


if __name__ == "__main__":
    main()
