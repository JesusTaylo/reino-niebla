"""Genera el ícono de la app (rosa de los vientos dorada sobre noche índigo)."""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

S = 1024
img = Image.new("RGBA", (S, S), (13, 16, 38, 255))
d = ImageDraw.Draw(img)

cx, cy = S / 2, S / 2

# Fondo con viñeta radial suave
glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
gd = ImageDraw.Draw(glow)
for r, a in [(500, 22), (420, 30), (340, 38)]:
    gd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(42, 52, 96, a))
glow = glow.filter(ImageFilter.GaussianBlur(60))
img = Image.alpha_composite(img, glow)
d = ImageDraw.Draw(img)

GOLD = (212, 175, 55, 255)
GOLD_SOFT = (232, 206, 122, 255)
PARCH = (240, 230, 210, 255)

# Anillo exterior
d.ellipse([cx - 400, cy - 400, cx + 400, cy + 400], outline=GOLD, width=22)
d.ellipse([cx - 352, cy - 352, cx + 352, cy + 352], outline=(212, 175, 55, 120), width=6)

# Rosa de los vientos: 4 puntas largas + 4 cortas
def point(angle_deg, length, width, color):
    a = math.radians(angle_deg)
    tip = (cx + length * math.sin(a), cy - length * math.cos(a))
    left = (cx + width * math.sin(a - math.pi / 2), cy - width * math.cos(a - math.pi / 2))
    right = (cx + width * math.sin(a + math.pi / 2), cy - width * math.cos(a + math.pi / 2))
    d.polygon([tip, left, right], fill=color)

for ang in [45, 135, 225, 315]:
    point(ang, 240, 42, (150, 122, 40, 255))
for ang in [0, 90, 180, 270]:
    point(ang, 330, 58, GOLD)
    # mitad sombreada para dar volumen
    a = math.radians(ang)
    tip = (cx + 330 * math.sin(a), cy - 330 * math.cos(a))
    left = (cx + 58 * math.sin(a - math.pi / 2), cy - 58 * math.cos(a - math.pi / 2))
    d.polygon([tip, left, (cx, cy)], fill=GOLD_SOFT)

# Centro
d.ellipse([cx - 70, cy - 70, cx + 70, cy + 70], fill=(13, 16, 38, 255), outline=GOLD, width=14)
d.ellipse([cx - 26, cy - 26, cx + 26, cy + 26], fill=GOLD_SOFT)

# Niebla inferior (bandas blancas translúcidas)
fog = Image.new("RGBA", (S, S), (0, 0, 0, 0))
fd = ImageDraw.Draw(fog)
for i, y in enumerate([760, 820, 880]):
    fd.ellipse([-200 + i * 120, y, S + 100 - i * 60, y + 220], fill=(230, 232, 240, 70 - i * 12))
fog = fog.filter(ImageFilter.GaussianBlur(38))
img = Image.alpha_composite(img, fog)

# Esquinas redondeadas (adaptive icons se recortan solos, pero por si acaso)
out_dir = os.path.join(os.path.dirname(__file__), "..", "android_res")
sizes = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}
for folder, size in sizes.items():
    path = os.path.join(out_dir, folder)
    os.makedirs(path, exist_ok=True)
    icon = img.resize((size, size), Image.LANCZOS)
    icon.save(os.path.join(path, "ic_launcher.png"))

img.resize((512, 512), Image.LANCZOS).save(os.path.join(out_dir, "icon_512.png"))
print("Iconos generados en", os.path.abspath(out_dir))
