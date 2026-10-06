"""Draws the game's 2D icon set (cartoon "sticker" style) into one sprite sheet.

    python tools/make_icons.py          -> assets/ui/icons.png  (+ assets/ui/icons_preview.png)

Each icon is drawn at 1024px out of simple shapes: every part gets its own gradient, a dark
outline and a white shine; the whole icon gets a thick dark outline and a soft shadow; then it is
shrunk to CELL px (smooth edges). The sheet is COLS x ROWS cells; UIKit.IMAGES (src/client/UIKit.lua)
lists where each icon sits - keep ORDER below in sync with it.
"""
import math
import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

S = 1024  # drawing size
CELL = 204  # size in the sheet
COLS, ROWS = 5, 4
INK = (27, 27, 51, 255)
OUTER = 34  # outline around the whole icon
INNER = 14  # outline around each part
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT = "C:/Windows/Fonts/ariblk.ttf"

# masks ---------------------------------------------------------------------------------------


def blank():
    return Image.new("L", (S, S), 0)


def ellipse(box):
    m = blank()
    ImageDraw.Draw(m).ellipse(box, fill=255)
    return m


def circle(cx, cy, r):
    return ellipse((cx - r, cy - r, cx + r, cy + r))


def poly(pts):
    m = blank()
    ImageDraw.Draw(m).polygon([tuple(p) for p in pts], fill=255)
    return m


def rrect(box, r):
    m = blank()
    ImageDraw.Draw(m).rounded_rectangle(box, radius=r, fill=255)
    return m


def rect(box):
    m = blank()
    ImageDraw.Draw(m).rectangle(box, fill=255)
    return m


def line(pts, width):
    m = blank()
    ImageDraw.Draw(m).line([tuple(p) for p in pts], fill=255, width=width, joint="curve")
    for p in (pts[0], pts[-1]):  # round caps
        ImageDraw.Draw(m).ellipse((p[0] - width / 2, p[1] - width / 2, p[0] + width / 2, p[1] + width / 2), fill=255)
    return m


def union(*ms):
    out = ms[0]
    for m in ms[1:]:
        out = ImageChops.lighter(out, m)
    return out


def inter(a, b):
    return ImageChops.multiply(a, b)


def sub(a, b):
    return ImageChops.subtract(a, b)


def rot(m, deg, center=(S / 2, S / 2)):
    return m.rotate(deg, resample=Image.BICUBIC, center=center)


def rot_pts(pts, deg, c=(S / 2, S / 2)):
    a = math.radians(deg)
    out = []
    for x, y in pts:
        dx, dy = x - c[0], y - c[1]
        out.append((c[0] + dx * math.cos(a) - dy * math.sin(a), c[1] + dx * math.sin(a) + dy * math.cos(a)))
    return out


def dilate(m, r):
    if r <= 0:
        return m
    b = m.filter(ImageFilter.GaussianBlur(r / 2))
    return b.point(lambda v: 0 if v < 3 else (255 if v > 13 else int((v - 3) * 25.5)))


def erode(m, r):
    return ImageChops.invert(dilate(ImageChops.invert(m), r))


def rounded(m, r):
    """Round off sharp corners."""
    return dilate(erode(m, r), r)


def star_pts(cx, cy, R, r, n=5, rot_deg=-90):
    pts = []
    for i in range(n * 2):
        a = math.radians(rot_deg + i * 180 / n)
        rad = R if i % 2 == 0 else r
        pts.append((cx + rad * math.cos(a), cy + rad * math.sin(a)))
    return pts


# painting ------------------------------------------------------------------------------------


def gradient(top, bottom, y0, y1, mid=None):
    g = Image.new("RGBA", (S, S))
    d = ImageDraw.Draw(g)
    for y in range(S):
        t = min(1, max(0, (y - y0) / max(1, y1 - y0)))
        if mid:
            c = lerp(top, mid, t * 2) if t < 0.5 else lerp(mid, bottom, t * 2 - 1)
        else:
            c = lerp(top, bottom, t)
        d.line((0, y, S, y), fill=c + (255,))
    return g


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def lighter(c, f):
    return lerp(c, (255, 255, 255), f)


def darker(c, f):
    return lerp(c, (0, 0, 0), f)


class Icon:
    def __init__(self):
        self.img = Image.new("RGBA", (S, S), (0, 0, 0, 0))

    def part(self, mask, color, outline=INNER, shade=True, top=None, bottom=None):
        """A filled shape with its own dark outline. color = base RGB; top/bottom override the gradient."""
        if outline:
            self.img.paste(INK, (0, 0), dilate(mask, outline))
        box = mask.getbbox()
        if not box:
            return
        if shade:
            g = gradient(top or lighter(color, 0.35), bottom or darker(color, 0.2), box[1], box[3], mid=color)
        else:
            g = Image.new("RGBA", (S, S), color + (255,))
        self.img.paste(g, (0, 0), mask)

    def shine(self, mask, area, alpha=0.5):
        """White highlight: area (a mask) clipped to mask."""
        hl = inter(mask, area).point(lambda v: int(v * alpha))
        self.img.paste((255, 255, 255, 255), (0, 0), hl)

    def lines(self, mask, alpha=1.0):
        """Dark detail lines (mask) drawn on top."""
        self.img.paste(INK, (0, 0), mask.point(lambda v: int(v * alpha)))

    def text(self, xy, s, size, fill, stroke=26):
        d = ImageDraw.Draw(self.img)
        d.text(xy, s, font=ImageFont.truetype(FONT, size), fill=fill + (255,), anchor="mm", stroke_width=stroke, stroke_fill=INK)

    def sparkle(self, cx, cy, R, color=(255, 245, 160)):
        self.part(poly(star_pts(cx, cy, R, R * 0.32, 4, -90)), color, outline=10)

    def rotate(self, deg):
        self.img = self.img.rotate(deg, resample=Image.BICUBIC, center=(S / 2, S / 2))

    def fit(self, margin=70):
        """Scale + center the drawing so it fills the canvas (minus margin for the outline)."""
        box = self.img.getbbox()
        if not box:
            return
        crop = self.img.crop(box)
        w, h = crop.size
        k = (S - 2 * margin) / max(w, h)
        crop = crop.resize((max(1, int(w * k)), max(1, int(h * k))), Image.LANCZOS)
        self.img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        self.img.paste(crop, ((S - crop.size[0]) // 2, (S - crop.size[1]) // 2), crop)

    def finish(self):
        self.fit()
        alpha = self.img.split()[3]
        ol = dilate(alpha, OUTER)
        out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        shadow.paste((10, 10, 30, 90), (0, 22), ol)
        out.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(6)))
        out.paste(INK, (0, 0), ol)
        out.alpha_composite(self.img)
        return out.resize((CELL, CELL), Image.LANCZOS)


# icons ---------------------------------------------------------------------------------------
RED = (240, 70, 75)
GOLD = (255, 200, 50)
WHITE = (250, 250, 255)


def rocket_body(ic, nose, flame):
    cx = 512
    body = union(ellipse((352, 140, 672, 780)), rrect((352, 420, 672, 770), 70))
    fin_l = rounded(poly([(372, 540), (240, 690), (226, 830), (300, 836), (380, 760)]), 22)
    fin_r = fin_l.transpose(Image.FLIP_LEFT_RIGHT)
    if flame:
        outer = union(ellipse((392, 760, 632, 940)), poly([(398, 860), (626, 860), (512, 1010)]))
        ic.part(outer, (255, 140, 40), top=(255, 210, 70), bottom=(255, 90, 30))
        ic.part(union(ellipse((447, 785, 577, 900)), poly([(450, 850), (574, 850), (512, 955)])), (255, 225, 90), outline=0, top=(255, 252, 200), bottom=(255, 200, 60))
    ic.part(fin_l, nose)
    ic.part(fin_r, nose)
    ic.part(rrect((412, 730, 612, 830), 26), (140, 145, 165))
    ic.part(body, WHITE, top=(255, 255, 255), bottom=(196, 204, 226))
    ic.part(inter(body, rect((0, 0, S, 335))), nose, outline=10)
    ic.part(inter(body, rect((0, 636, S, 698))), nose, outline=10)
    ic.part(circle(cx, 470, 96), (215, 222, 238), outline=12)
    win = circle(cx, 470, 64)
    ic.part(win, (90, 180, 245), top=(170, 235, 255), bottom=(50, 120, 220), outline=10)
    ic.shine(win, ellipse((470, 420, 520, 470)), 0.9)
    ic.shine(body, ellipse((380, 210, 462, 640)), 0.6)


def icon_rocket():
    ic = Icon()
    rocket_body(ic, RED, flame=True)
    ic.rotate(-40)
    ic.sparkle(250, 230, 70)
    ic.sparkle(800, 760, 50)
    return ic


def icon_rockets():
    ic = Icon()
    rocket_body(ic, (70, 150, 255), flame=False)
    ic.rotate(-18)
    ic.sparkle(230, 260, 80)
    ic.sparkle(800, 300, 56)
    ic.sparkle(790, 760, 44)
    return ic


def icon_upgrade():
    ic = Icon()
    arrow = rounded(poly([(512, 110), (880, 490), (680, 490), (680, 900), (344, 900), (344, 490), (144, 490)]), 34)
    ic.part(arrow, (70, 205, 80), top=(170, 255, 140), bottom=(30, 150, 50))
    ic.shine(arrow, poly([(512, 150), (512, 860), (380, 860), (380, 470), (220, 470)]), 0.35)
    ic.sparkle(830, 210, 80)
    ic.sparkle(190, 760, 56)
    return ic


def icon_paw():
    ic = Icon()
    color = (205, 135, 85)
    pad = union(ellipse((300, 520, 724, 870)), ellipse((360, 480, 664, 700)))
    ic.part(pad, color)
    ic.shine(pad, ellipse((350, 540, 520, 660)), 0.5)
    for cx, cy, ang in ((240, 455, -28), (408, 290, -9), (616, 290, 9), (784, 455, 28)):
        toe = rot(ellipse((cx - 78, cy - 100, cx + 78, cy + 100)), -ang, (cx, cy))
        ic.part(toe, color)
        ic.shine(toe, ellipse((cx - 50, cy - 80, cx - 5, cy - 20)), 0.55)
    return ic


def icon_store():
    ic = Icon()
    handle = sub(ellipse((360, 150, 664, 520)), ellipse((420, 210, 604, 460)))
    ic.part(inter(handle, rect((0, 0, S, 420))), (200, 60, 90))
    bag = rounded(poly([(250, 360), (774, 360), (820, 900), (204, 900)]), 40)
    ic.part(bag, (245, 85, 120), top=(255, 140, 165), bottom=(200, 45, 85))
    ic.part(inter(bag, rect((0, 0, S, 440))), (215, 60, 100), outline=10)
    ic.shine(bag, poly([(260, 450), (360, 450), (330, 880), (225, 880)]), 0.35)
    st = rounded(poly(star_pts(512, 660, 170, 72)), 14)
    ic.part(st, GOLD, top=(255, 245, 140), bottom=(250, 160, 30))
    return ic


def icon_wheel():
    ic = Icon()
    cx, cy, R = 512, 560, 380
    ic.part(circle(cx, cy, R), GOLD, top=(255, 235, 130), bottom=(220, 140, 30))
    colors = [(255, 85, 95), (255, 215, 70), (75, 165, 255), (110, 215, 90)]
    inner = R - 52
    for i in range(8):
        m = blank()
        ImageDraw.Draw(m).pieslice((cx - inner, cy - inner, cx + inner, cy + inner), -90 + i * 45, -45 + i * 45, fill=255)
        ic.part(m, colors[i % 4], outline=0)
    seps = blank()
    d = ImageDraw.Draw(seps)
    for i in range(8):
        a = math.radians(-90 + i * 45)
        d.line((cx, cy, cx + inner * math.cos(a), cy + inner * math.sin(a)), fill=255, width=16)
    d.ellipse((cx - inner, cy - inner, cx + inner, cy + inner), outline=255, width=16)
    ic.lines(seps)
    for i in range(8):
        a = math.radians(-67.5 + i * 45)
        ic.part(circle(cx + (R - 26) * math.cos(a), cy + (R - 26) * math.sin(a), 16), (255, 255, 230), outline=6, shade=False)
    ic.shine(circle(cx, cy, inner), ellipse((cx - inner, cy - inner, cx + 40, cy - 20)), 0.3)
    ic.part(circle(cx, cy, 74), WHITE, top=(255, 255, 255), bottom=(190, 195, 215))
    ic.part(rounded(poly([(432, 90), (592, 90), (512, 270)]), 18), RED, top=(255, 130, 130), bottom=(200, 40, 50))
    return ic


def icon_clipboard():
    ic = Icon()
    ic.part(rrect((220, 170, 804, 930), 64), (180, 115, 65), top=(215, 150, 90), bottom=(140, 85, 45))
    ic.part(rrect((285, 255, 739, 870), 26), WHITE, top=(255, 255, 255), bottom=(222, 228, 242), outline=10)
    clip = sub(rrect((390, 110, 634, 265), 44), rrect((470, 140, 554, 190), 24))
    ic.part(clip, (200, 205, 220), top=(240, 242, 250), bottom=(140, 145, 165))
    for i, y in enumerate((395, 545, 695)):
        ic.part(rrect((330, y - 48, 426, y + 48), 20), (235, 238, 248), outline=10)
        ic.part(rrect((460, y - 20, 700, y + 20), 20), (190, 196, 215), outline=0, shade=False)
        if i < 2:
            ic.part(line([(346, y - 2), (378, y + 32), (440, y - 46)], 38), (70, 205, 85), outline=10)
    return ic


def icon_calendar():
    ic = Icon()
    page = rrect((190, 230, 834, 890), 64)
    ic.part(page, WHITE, top=(255, 255, 255), bottom=(220, 226, 242))
    ic.part(inter(page, rect((0, 0, S, 405))), (240, 75, 85), outline=10, top=(255, 125, 125), bottom=(205, 45, 60))
    for x in (330, 694):
        ic.part(rrect((x - 30, 140, x + 30, 310), 30), (200, 205, 220), top=(240, 242, 250), bottom=(140, 145, 165))
    st = rounded(poly(star_pts(512, 650, 200, 86)), 16)
    ic.part(st, GOLD, top=(255, 245, 140), bottom=(250, 160, 30))
    ic.shine(st, ellipse((380, 500, 520, 640)), 0.45)
    return ic


def icon_gift():
    ic = Icon()
    teal = (40, 185, 225)
    # bow: two rounded lobes fanning out from the knot, each with a darker fold
    lobe_l = rounded(poly([(512, 340), (250, 170), (215, 250), (250, 380)]), 40)
    lobe_r = lobe_l.transpose(Image.FLIP_LEFT_RIGHT)
    for lobe in (lobe_l, lobe_r):
        ic.part(lobe, GOLD, top=(255, 240, 140), bottom=(235, 160, 30))
    fold_l = rounded(poly([(500, 340), (330, 255), (320, 300), (350, 345)]), 20)
    for fold in (fold_l, fold_l.transpose(Image.FLIP_LEFT_RIGHT)):
        ic.part(fold, (225, 145, 25), outline=0, shade=False)
    body = rrect((235, 480, 789, 900), 30)
    ic.part(body, teal, top=(110, 225, 250), bottom=(25, 135, 195))
    ic.part(inter(body, rect((457, 0, 567, S))), GOLD, outline=10)
    lid = rrect((185, 360, 839, 510), 34)
    ic.part(lid, teal, top=(140, 235, 255), bottom=(30, 160, 210))
    ic.part(inter(lid, rect((447, 0, 577, S))), GOLD, outline=10)
    ic.part(circle(512, 330, 62), GOLD, top=(255, 240, 140), bottom=(235, 160, 30))
    ic.shine(body, rect((260, 500, 330, 880)), 0.3)
    ic.shine(lid, rect((205, 375, 430, 410)), 0.5)
    return ic


def icon_coin():
    ic = Icon()
    c = circle(512, 512, 380)
    ic.part(c, GOLD, top=(255, 240, 140), bottom=(225, 145, 25))
    ic.part(circle(512, 512, 300), (250, 185, 40), outline=10, top=(240, 165, 30), bottom=(255, 215, 90))
    ic.text((512, 520), "$", 470, (255, 245, 190), stroke=24)
    ic.shine(c, ellipse((200, 170, 470, 420)), 0.45)
    return ic


def icon_trophy():
    ic = Icon()
    gold = (250, 195, 45)
    for flip in (False, True):
        h = sub(ellipse((170, 250, 380, 520)), ellipse((222, 300, 330, 470)))
        h = inter(h, rect((0, 0, 400, S)))
        ic.part(h.transpose(Image.FLIP_LEFT_RIGHT) if flip else h, gold)
    ic.part(rrect((462, 600, 562, 740), 10), gold)
    ic.part(rrect((420, 700, 604, 770), 26), gold)
    ic.part(rrect((300, 760, 724, 900), 34), (140, 85, 55), top=(175, 115, 75), bottom=(100, 60, 35))
    ic.part(rrect((430, 798, 594, 860), 16), (255, 215, 90), outline=8)
    cup = union(rect((300, 170, 724, 400)), ellipse((300, 220, 724, 660)))
    ic.part(rounded(cup, 30), gold, top=(255, 240, 140), bottom=(215, 135, 20))
    ic.part(rounded(poly(star_pts(512, 400, 120, 52)), 10), (255, 245, 200), outline=10, top=(255, 255, 235), bottom=(255, 215, 110))
    ic.shine(cup, ellipse((330, 200, 440, 560)), 0.45)
    return ic


def icon_gear():
    ic = Icon()
    teeth = blank()
    for i in range(8):
        pts = rot_pts([(452, 110), (572, 110), (590, 300), (434, 300)], i * 45)
        teeth = union(teeth, poly(pts))
    gear = rounded(union(teeth, circle(512, 512, 320)), 22)
    ic.part(gear, (150, 165, 200), top=(215, 225, 245), bottom=(100, 110, 145))
    ic.part(circle(512, 512, 130), (90, 100, 135), outline=12, top=(70, 78, 110), bottom=(130, 140, 175))
    ic.shine(gear, ellipse((250, 200, 520, 420)), 0.4)
    return ic


def icon_crown():
    ic = Icon()
    for x, y in ((190, 300), (512, 220), (834, 300)):
        ic.part(circle(x, y, 52), GOLD, top=(255, 240, 140), bottom=(225, 150, 25))
    spikes = rounded(poly([(240, 700), (190, 320), (370, 500), (512, 250), (654, 500), (834, 320), (784, 700)]), 26)
    ic.part(spikes, GOLD, top=(255, 240, 140), bottom=(225, 150, 25))
    band = rrect((220, 640, 804, 800), 34)
    ic.part(band, (245, 175, 40), top=(255, 210, 80), bottom=(210, 125, 20))
    for x, col in ((350, (240, 70, 90)), (512, (70, 150, 255)), (674, (90, 210, 100))):
        gem = circle(x, 720, 46)
        ic.part(gem, col, outline=10)
        ic.shine(gem, circle(x - 14, 706, 16), 0.9)
    ic.shine(spikes, poly([(230, 640), (210, 380), (330, 520), (300, 640)]), 0.4)
    return ic


def icon_bolt():
    ic = Icon()
    bolt = rounded(poly([(620, 90), (250, 560), (480, 560), (390, 940), (790, 400), (560, 400), (690, 90)]), 22)
    ic.part(bolt, (255, 215, 50), top=(255, 250, 160), bottom=(250, 165, 20))
    ic.shine(bolt, poly([(600, 130), (330, 520), (420, 520), (640, 140)]), 0.55)
    return ic


def icon_fuelcan():
    ic = Icon()
    red = (230, 55, 55)
    ic.part(rot(rrect((610, 130, 700, 330), 24), -30, (655, 330)), (255, 205, 60))
    handle = sub(rrect((250, 160, 590, 340), 60), rrect((320, 210, 520, 290), 34))
    ic.part(handle, red)
    body = rrect((220, 270, 804, 910), 70)
    ic.part(body, red, top=(255, 120, 110), bottom=(185, 30, 35))
    ic.lines(union(line([(330, 420), (694, 800)], 26), line([(694, 420), (330, 800)], 26)), 0.45)
    ic.part(rrect((260, 300, 330, 880), 30), (255, 140, 130), outline=0, shade=False)
    return ic


def icon_moneybag():
    ic = Icon()
    tan = (225, 185, 120)
    ic.part(rounded(poly([(360, 130), (512, 260), (664, 130), (640, 330), (384, 330)]), 30), tan)
    sack = union(ellipse((200, 360, 824, 920)), rrect((400, 300, 624, 480), 40))
    ic.part(sack, tan, top=(245, 215, 160), bottom=(180, 135, 75))
    ic.part(rrect((380, 300, 644, 370), 30), (210, 75, 75), outline=10)
    ic.text((512, 660), "$", 360, (90, 200, 90), stroke=22)
    ic.shine(sack, ellipse((250, 430, 420, 700)), 0.4)
    return ic


def heart_mask(cx, cy, size, ang=0):
    s = size / 600
    pts = lambda x, y: (cx + (x - 512) * s, cy + (y - 512) * s)
    m = union(
        ellipse((*pts(210, 230), *pts(530, 550))),
        ellipse((*pts(494, 230), *pts(814, 550))),
        poly([pts(222, 440), pts(802, 440), pts(512, 840)]),
    )
    m = rounded(m, max(4, int(18 * s)))
    return rot(m, -ang, (cx, cy)) if ang else m


def icon_heart():
    ic = Icon()
    h = heart_mask(512, 512, 600)
    ic.part(h, (240, 60, 95), top=(255, 130, 150), bottom=(200, 30, 70))
    ic.shine(h, ellipse((260, 270, 440, 420)), 0.6)
    return ic


def icon_clover():
    ic = Icon()
    green = (70, 190, 80)
    ic.part(line([(512, 560), (560, 760), (660, 900)], 52), (50, 150, 60))
    for ang in (0, 90, 180, 270):
        a = math.radians(ang - 90)
        cx, cy = 512 + 175 * math.cos(a), 512 + 175 * math.sin(a)
        h = heart_mask(cx, cy, 340, ang)  # (each leaf's tip points at the middle)
        ic.part(h, green, top=(150, 240, 120), bottom=(40, 150, 55))
        ic.shine(h, circle(cx - 40, cy - 40, 45), 0.4)
    ic.part(circle(512, 512, 40), (60, 170, 70), outline=8)
    return ic


def icon_rainbow():
    ic = Icon()
    cx, cy = 512, 720
    colors = [(240, 70, 80), (255, 150, 50), (255, 215, 60), (90, 205, 90), (70, 150, 255), (150, 95, 235)]
    R, w = 430, 52
    for i, col in enumerate(colors):
        ro, ri = R - i * w, R - (i + 1) * w
        band = inter(sub(circle(cx, cy, ro), circle(cx, cy, ri)), rect((0, 0, S, cy)))
        ic.part(band, col, outline=0, shade=False)
    arc = inter(sub(circle(cx, cy, R), circle(cx, cy, R - len(colors) * w)), rect((0, 0, S, cy)))
    edge = sub(dilate(arc, 12), arc)
    ic.lines(edge)
    for x in (cx - R + 150, cx + R - 150):
        cloud = union(circle(x - 90, 740, 85), circle(x, 690, 110), circle(x + 95, 745, 85), rrect((x - 170, 720, x + 175, 830), 55))
        ic.part(cloud, WHITE, top=(255, 255, 255), bottom=(205, 215, 235))
    return ic


# name (as used in UIKit) -> drawing; the sheet is filled left to right, top to bottom
ORDER = [
    ("Rocket", icon_rocket),
    ("Rockets", icon_rockets),
    ("Upgrade", icon_upgrade),
    ("Paw", icon_paw),
    ("Store", icon_store),
    ("Wheel", icon_wheel),
    ("Scroll", icon_clipboard),
    ("Calendar", icon_calendar),
    ("Gift", icon_gift),
    ("Coin", icon_coin),
    ("Trophy", icon_trophy),
    ("Gear", icon_gear),
    ("Crown", icon_crown),
    ("Bolt", icon_bolt),
    ("FuelCan", icon_fuelcan),
    ("MoneyBag", icon_moneybag),
    ("Heart", icon_heart),
    ("Clover", icon_clover),
    ("Rainbow", icon_rainbow),
]


def main():
    sheet = Image.new("RGBA", (COLS * CELL, ROWS * CELL), (0, 0, 0, 0))
    for i, (name, fn) in enumerate(ORDER):
        img = fn().finish()
        sheet.paste(img, ((i % COLS) * CELL, (i // COLS) * CELL), img)
        print(i, name)
    out = os.path.join(ROOT, "assets", "ui", "icons.png")
    sheet.save(out)
    # a preview on the HUD tile colors, to judge contrast
    prev = Image.new("RGBA", sheet.size, (60, 60, 80, 255))
    tiles = [(255, 130, 30), (70, 140, 255), (165, 105, 245), (255, 120, 190), (255, 180, 40)]
    d = ImageDraw.Draw(prev)
    for i in range(COLS * ROWS):
        x, y = (i % COLS) * CELL, (i // COLS) * CELL
        d.rounded_rectangle((x + 6, y + 6, x + CELL - 6, y + CELL - 6), radius=30, fill=tiles[i % len(tiles)] + (255,))
    prev.alpha_composite(sheet)
    prev.save(os.path.join(ROOT, "assets", "ui", "icons_preview.png"))
    print("saved", out)


if __name__ == "__main__":
    main()
