"""Turns raw iPhone screenshots into App Store screenshots in Mino's style.

Each screenshot gets a cream background, a short promise on top and rounded corners, at the
size App Store Connect asks for iPhone 6.3" displays (1206 x 2622).

Usage: python3 design/appstore/frame.py <raw screenshots folder> <output folder>
Screenshots are matched to captions by the number their file name starts with (1.png, 2.png…).
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

WIDTH, HEIGHT = 1206, 2622
CREAM, INK, ACCENT = "#FAF5EC", "#2B3245", "#34587A"
FONT = Path(__file__).parent / "fonts" / "Nunito.ttf"

CAPTIONS = {
    1: ("La tenue du jour,", "prête selon la météo"),
    2: ("Anticipez la taille d'après,", "sans mauvaise surprise"),
    3: ("Ce soir,", "demain est déjà prêt"),
    4: ("Toute une pile ajoutée", "en quelques photos"),
    5: ("Son dressing,", "toujours à jour"),
    6: ("Chaque vêtement,", "et sa prochaine vie"),
    7: ("Il s'habille seul,", "pièce par pièce"),
    8: ("Toutes les tenues,", "jour après jour"),
}


def font(size, weight):
    face = ImageFont.truetype(str(FONT), size)
    face.set_variation_by_axes([weight])
    return face


def frame(shot: Image.Image, lines) -> Image.Image:
    canvas = Image.new("RGB", (WIDTH, HEIGHT), CREAM)
    draw = ImageDraw.Draw(canvas)
    first, second = font(78, 800), font(78, 600)
    y = 150
    for text, face, color in ((lines[0], first, INK), (lines[1], second, ACCENT)):
        box = draw.textbbox((0, 0), text, font=face)
        draw.text(((WIDTH - (box[2] - box[0])) / 2, y), text, font=face, fill=color)
        y += 104
    # The screenshot, slightly smaller than the page, with rounded corners and a soft shadow.
    top = y + 70
    width = min(int(WIDTH * 0.84), int((HEIGHT - top - 90) * shot.width / shot.height))
    height = int(shot.height * width / shot.width)
    shot = shot.convert("RGB").resize((width, height), Image.LANCZOS)
    radius = 70
    mask = Image.new("L", (width, height), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, width - 1, height - 1), radius, fill=255)
    left = (WIDTH - width) // 2
    shadow = Image.new("L", (WIDTH, HEIGHT), 0)
    ImageDraw.Draw(shadow).rounded_rectangle((left, top + 18, left + width, top + height + 18), radius, fill=70)
    shadow = shadow.filter(ImageFilter.GaussianBlur(28))
    canvas.paste(Image.new("RGB", (WIDTH, HEIGHT), "#8A7A66"), (0, 0), shadow)
    canvas.paste(shot, (left, top), mask)
    return canvas


def main():
    source, output = Path(sys.argv[1]), Path(sys.argv[2])
    output.mkdir(parents=True, exist_ok=True)
    for path in sorted(source.iterdir()):
        number = int("".join(c for c in path.stem if c.isdigit()) or 0)
        if number in CAPTIONS:
            frame(Image.open(path), CAPTIONS[number]).save(output / f"Mino-{number}.png")
            print("framed", path.name)


if __name__ == "__main__":
    main()
