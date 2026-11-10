# Génère Resources/AppIcon.icns : la MX Master (dessin Resources/souris-dessus.png)
# en crème sur fond terracotta, avec la molette et le bouton de pouce.
# Usage : python3 tools/make-icon.py   (nécessite Pillow)
import os, subprocess
from PIL import Image, ImageDraw, ImageFilter

S = 1024

def icon():
    bg = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    m, r = 100, 185  # gabarit macOS : carré arrondi de 824/1024
    grad = Image.new('RGBA', (S, S))
    top, bot = (226, 128, 92), (196, 92, 58)
    for y in range(S):
        t = y / S
        grad.paste(tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)) + (255,), (0, y, S, y + 1))
    mask = Image.new('L', (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle((m, m, S - m, S - m), r, fill=255)
    sh = Image.new('L', (S, S), 0)
    ImageDraw.Draw(sh).rounded_rectangle((m, m + 12, S - m, S - m + 12), r, fill=90)
    bg.paste((0, 0, 0, 255), (0, 0), sh.filter(ImageFilter.GaussianBlur(18)))
    bg.paste(grad, (0, 0), mask)

    src = Image.open('Resources/souris-dessus.png')
    a = src.split()[3]
    h = 580; w = int(src.width * h / src.height)
    a = a.resize((w, h), Image.LANCZOS)
    ox, oy, k = (S - w) // 2 + 12, (S - h) // 2 + 6, h / src.height
    bg.paste(Image.new('RGBA', (w, h), (251, 248, 245, 255)), (ox, oy), a)

    d = ImageDraw.Draw(bg); dark = (150, 62, 36, 255)
    X = lambda x: ox + x * k; Y = lambda y: oy + y * k
    d.line((X(272), Y(40), X(272), Y(95)), fill=dark, width=9)
    d.rounded_rectangle((X(272) - 17, Y(100), X(272) + 17, Y(205)), 17, fill=dark)
    d.line((X(272), Y(212), X(272), Y(300)), fill=dark, width=9)
    cx, cy, R = X(39) + 40, Y(447), 30
    d.ellipse((cx - R, cy - R, cx + R, cy + R), fill=dark)
    return bg

ic = icon()
ic.save('Design/icone-1024.png')
iconset = 'build/AppIcon.iconset'
os.makedirs(iconset, exist_ok=True)
for s in (16, 32, 128, 256, 512):
    ic.resize((s, s), Image.LANCZOS).save(f'{iconset}/icon_{s}x{s}.png')
    ic.resize((s * 2, s * 2), Image.LANCZOS).save(f'{iconset}/icon_{s}x{s}@2x.png')
subprocess.run(['iconutil', '-c', 'icns', iconset, '-o', 'Resources/AppIcon.icns'], check=True)
