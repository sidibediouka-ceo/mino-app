"""Sets the status bar clock of iPhone screenshots to 9:41, as on Apple's own product shots.

The old time (and the location arrow) are painted out by diffusing the surrounding pixels,
so blurred content behind the status bar stays intact; 9:41 is drawn where iOS puts it.

Usage: python3 design/appstore/status_time.py <screenshot> <output>   (1179 x 2556 screenshots)
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

FONT = Path(__file__).parent / "fonts" / "Inter.ttf"
AREA = (60, 30, 360, 125)           # left status bar zone where the clock lives
DIGITS_TOP, DIGITS_BOTTOM = 69, 106  # iOS clock digits, in pixels, on a 1179-wide screenshot
CENTRE_X = 214


def paint_out(image):
    pixels = np.asarray(image, dtype=np.float32).copy()
    x0, y0, x1, y1 = AREA
    zone = pixels[y0:y1, x0:x1]
    dark = (zone.sum(axis=2) < 330)
    mask = Image.fromarray((dark * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(9))
    hole = np.asarray(mask) > 0
    # Seed the hole with the mean of its border, then let neighbours diffuse inwards.
    zone[hole] = zone[~hole].mean(axis=0)
    for _ in range(400):
        blurred = (np.roll(zone, 1, 0) + np.roll(zone, -1, 0) + np.roll(zone, 1, 1) + np.roll(zone, -1, 1)) / 4
        zone[hole] = blurred[hole]
    pixels[y0:y1, x0:x1] = zone
    return Image.fromarray(pixels.clip(0, 255).astype(np.uint8))


def clock_font():
    size = 40
    while True:
        face = ImageFont.truetype(str(FONT), size)
        face.set_variation_by_axes([14, 620])
        box = face.getbbox("9:41")
        if box[3] - box[1] >= DIGITS_BOTTOM - DIGITS_TOP + 1:
            return face
        size += 1


def main():
    image = Image.open(sys.argv[1]).convert("RGB")
    image = paint_out(image)
    face = clock_font()
    box = face.getbbox("9:41")
    draw = ImageDraw.Draw(image)
    draw.text((CENTRE_X - (box[2] - box[0]) / 2 - box[0], DIGITS_TOP - box[1]), "9:41", font=face, fill=(0, 0, 0))
    image.save(sys.argv[2])


if __name__ == "__main__":
    main()
