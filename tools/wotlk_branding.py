import sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter
src, dst, font_path = sys.argv[1], sys.argv[2], sys.argv[3]
color = tuple(int(c) for c in sys.argv[4].split(','))
glow = float(sys.argv[5])
TEXT = "WRATH OF THE LICH KING"
X0, X1, Y = 134, 236, 113          # under "EllesmereUI" (x 134-236, y 95-109)
SS = 8                              # supersample factor
raw = open(src, 'rb').read()
hdr, body = raw[:18], raw[18:18+1024*1024*4]
img = Image.frombytes('RGBA', (1024, 1024), body, 'raw', 'BGRA')
# Fit cap height ~6px with tracking so the line spans the wordmark width
font = ImageFont.truetype(font_path, 7 * SS)
widths = [font.getlength(c) for c in TEXT]
target = (X1 - X0) * SS
track = (target - sum(widths)) / (len(TEXT) - 1)
W, H = (X1 - X0 + 8) * SS, 14 * SS
mask = Image.new('L', (W, H), 0)
d = ImageDraw.Draw(mask)
x = 4 * SS
asc = font.getbbox("W")[1]
for c, w in zip(TEXT, widths):
    d.text((x, 2 * SS - asc), c, font=font, fill=255)
    x += w + track
mask = mask.resize((W // SS, H // SS), Image.LANCZOS)
ox, oy = X0 - 4, Y - 2
region = img.crop((ox, oy, ox + mask.width, oy + mask.height))
if glow > 0:
    g = mask.filter(ImageFilter.GaussianBlur(1.6)).point(lambda v: int(min(255, v * glow)))
    region = Image.composite(Image.new('RGBA', region.size, color + (255,)), region, g.point(lambda v: v // 2))
region = Image.composite(Image.new('RGBA', region.size, color + (255,)), region, mask)
img.paste(region, (ox, oy))
open(dst, 'wb').write(hdr + img.tobytes('raw', 'BGRA') + raw[18+1024*1024*4:])
