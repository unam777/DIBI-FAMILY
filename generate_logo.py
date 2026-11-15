from PIL import Image, ImageDraw, ImageFont
import os

size = 1024
img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# Background rounded square #0B5C3F
radius = int(size * 0.26)
draw.rounded_rectangle([0, 0, size, size], radius=radius, fill='#0B5C3F')

# Dot bottom right #FFD700
dot_radius = int(size * 0.035)
dot_cx = int(size * 0.88)
dot_cy = int(size * 0.88)
draw.ellipse([dot_cx - dot_radius, dot_cy - dot_radius, dot_cx + dot_radius, dot_cy + dot_radius], fill='#FFD700')

try:
    font = ImageFont.truetype("times.ttf", int(size * 0.55))
except:
    try:
        font = ImageFont.truetype("arial.ttf", int(size * 0.55))
    except:
        font = ImageFont.load_default()

# Draw K centered
bbox = draw.textbbox((0, 0), "K", font=font)
w = bbox[2] - bbox[0]
h = bbox[3] - bbox[1]
x = (size - w) / 2 - bbox[0] - int(size * 0.02)
y = (size - h) / 2 - bbox[1] - int(size * 0.03)
draw.text((x, y), "K", fill='white', font=font)

# Draw gold coins and arrow
gold = '#FFD700'
draw.ellipse([int(size*0.52), int(size*0.32), int(size*0.62), int(size*0.42)], fill=gold, outline='#C59B00', width=2)
draw.ellipse([int(size*0.62), int(size*0.24), int(size*0.72), int(size*0.34)], fill=gold, outline='#C59B00', width=2)
draw.ellipse([int(size*0.72), int(size*0.14), int(size*0.82), int(size*0.24)], fill=gold, outline='#C59B00', width=2)

# Arrow
draw.line([(int(size*0.48), int(size*0.30)), (int(size*0.85), int(size*0.06))], fill=gold, width=6)
draw.line([(int(size*0.85), int(size*0.06)), (int(size*0.72), int(size*0.06))], fill=gold, width=6)
draw.line([(int(size*0.85), int(size*0.06)), (int(size*0.85), int(size*0.19))], fill=gold, width=6)

os.makedirs('assets/images', exist_ok=True)
img.save('assets/images/kota_logo.png')
print("Kota logo generated successfully at assets/images/kota_logo.png")
