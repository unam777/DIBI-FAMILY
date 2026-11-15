from PIL import Image, ImageDraw, ImageFont
import os

size = 1024
scale = 2.0

img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# Background rect #0B5C3F, rx=110 -> 220
radius = int(110 * scale)
draw.rounded_rectangle([0, 0, size, size], radius=radius, fill='#0B5C3F')

# White K text (x=205, y=395, size=290 -> x=410, y=790, size=580)
try:
    font = ImageFont.truetype("times.ttf", int(290 * scale))
except:
    try:
        font = ImageFont.truetype("arial.ttf", int(290 * scale))
    except:
        font = ImageFont.load_default()

# Draw K at exact SVG center coordinate (205, 395)
draw.text((int(205 * scale), int(290 * scale)), "K", fill='white', font=font, anchor="mm")

# Gold ellipses (scaled by 2)
gold = '#D4AF37'
stroke_color = '#B8962E'

def draw_ellipse(cx, cy, rx, ry):
    box = [int((cx - rx) * scale), int((cy - ry) * scale), int((cx + rx) * scale), int((cy + ry) * scale)]
    draw.ellipse(box, fill=gold, outline=stroke_color, width=2)

# Petite pile
for cy in [290, 285, 280]:
    draw_ellipse(225, cy, 16, 5)

# Pile moyenne
for cy in [290, 283, 276, 269, 262]:
    draw_ellipse(265, cy, 20, 6)

# Grande pile
for cy in [290, 282, 274, 266, 258, 250, 242]:
    draw_ellipse(310, cy, 22, 6)

# Arrow path: M 335 225 L 405 145 M 405 145 L 380 145 M 405 145 L 405 170
pts = [
    (335, 225), (405, 145),
    (405, 145), (380, 145),
    (405, 145), (405, 170)
]
scaled_pts = [(int(p[0] * scale), int(p[1] * scale)) for p in pts]

for i in range(0, len(scaled_pts), 2):
    draw.line([scaled_pts[i], scaled_pts[i+1]], fill=gold, width=int(4 * scale))

# Dot bottom right: cx=445, cy=445, r=6 -> cx=890, cy=890, r=12
dot_cx = int(445 * scale)
dot_cy = int(445 * scale)
dot_r = int(8 * scale)
draw.ellipse([dot_cx - dot_r, dot_cy - dot_r, dot_cx + dot_r, dot_cy + dot_r], fill=gold)

os.makedirs('assets/images', exist_ok=True)
img.save('assets/images/kota_logo.png')
print("Exact SVG logo rendered and saved to assets/images/kota_logo.png")
