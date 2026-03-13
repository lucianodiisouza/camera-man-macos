#!/usr/bin/env python3
"""Generate the DMG background image for CameraMan — Dark Gray concept."""

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    import subprocess, sys
    subprocess.check_call([sys.executable, "-m", "pip", "install", "pillow", "-q"])
    from PIL import Image, ImageDraw, ImageFont

# window-size passado ao create-dmg: 640 x 400
# a imagem deve cobrir só a área de conteúdo (sem o chrome do Finder ~28px)
W, H = 640, 372
BG  = (26, 26, 26)   # #1a1a1a
RED = (255, 32, 32)
RED_DIM = (255, 32, 32)

img  = Image.new("RGB", (W, H), BG)
draw = ImageDraw.Draw(img)

# ── Corner brackets ──────────────────────────────
MARGIN = 20   # distance from edge
ARM    = 36   # length of each bracket arm
THICK  = 7    # line thickness
RAD    = 4    # border-radius

def bracket(ox, oy, flip_x, flip_y):
    """Draw one L-shaped bracket. flip_x/y mirror it to the right/bottom."""
    sx = 1 if not flip_x else -1
    sy = 1 if not flip_y else -1
    # vertical arm
    x0 = ox if not flip_x else ox - THICK
    y0 = oy
    x1 = x0 + THICK
    y1 = oy + sy * ARM
    draw.rounded_rectangle([min(x0,x1), min(y0,y1), max(x0,x1), max(y0,y1)], radius=RAD, fill=RED)
    # horizontal arm
    x0 = ox
    y0 = oy if not flip_y else oy - THICK
    x1 = ox + sx * ARM
    y1 = y0 + THICK
    draw.rounded_rectangle([min(x0,x1), min(y0,y1), max(x0,x1), max(y0,y1)], radius=RAD, fill=RED)

bracket(MARGIN,   MARGIN,   False, False)  # top-left
bracket(W-MARGIN, MARGIN,   True,  False)  # top-right
bracket(MARGIN,   H-MARGIN, False, True)   # bottom-left
bracket(W-MARGIN, H-MARGIN, True,  True)   # bottom-right

# ── REC badge ────────────────────────────────────
try:
    font_rec = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", 13)
    font_tc  = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", 10)
except Exception:
    font_rec = ImageFont.load_default()
    font_tc  = font_rec

DOT_R   = 5
GAP     = 7
rec_txt = "REC"
bbox    = draw.textbbox((0, 0), rec_txt, font=font_rec)
txt_w   = bbox[2] - bbox[0]
txt_h   = bbox[3] - bbox[1]
total_w = DOT_R * 2 + GAP + txt_w
sx      = (W - total_w) // 2
rec_y   = 16

draw.ellipse([sx, rec_y, sx + DOT_R*2, rec_y + DOT_R*2], fill=RED)
draw.text((sx + DOT_R*2 + GAP, rec_y - 1), rec_txt, fill=RED, font=font_rec)

# ── Arrow (center between icon x=130 and apps x=390) ─────────────────────────
AX1, AX2, AY = 270, 390, H // 2
TIP = 18   # arrowhead size
ATHICK = 5

# line
draw.rounded_rectangle([AX1, AY - ATHICK//2, AX2 - TIP, AY + ATHICK//2], radius=3, fill=RED)
# arrowhead
draw.polygon([(AX2 - TIP, AY - TIP//2 - 3), (AX2, AY), (AX2 - TIP, AY + TIP//2 + 3)], fill=RED)

# ── Timecode ─────────────────────────────────────
tc      = "00:01:24:08"
tc_bbox = draw.textbbox((0, 0), tc, font=font_tc)
tc_w    = tc_bbox[2] - tc_bbox[0]
draw.text(((W - tc_w) // 2, H - 26), tc, fill=(180, 20, 20), font=font_tc)

out = "dmg-background.png"
img.save(out)
print(f"✓ {out} ({W}×{H})")
