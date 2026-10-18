#!/usr/bin/env python3
"""Builds the encom-boardroom Plymouth theme into plymouth-theme/build/.

Plymouth's script plugin can only show images and plain text, so everything
static is drawn here with PIL: the light table frame, headers and panels of
the SDDM theme (sddm-theme/Main.qml), on a 1920x1080 canvas. The same layout
numbers fill in the placeholders of encom-boardroom.script.in, which animates
the boot terminal, the progress bar, the DANI-IDEAS badge and the thumbprint.

    python3 plymouth-theme/make-theme.py
"""

import os
import shutil
import subprocess

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(HERE, "build")
NAME = "encom-boardroom"

# The SDDM theme lays out a 1580x800 stage scaled to fit; on 1920x1080 that's
# a 1.215 scale with 54px bars above and below. Stage coordinates below are
# the ones in sddm-theme/Main.qml.
W, H = 1920, 1080
K = min(W / 1580, H / 800)
OX, OY = (W - 1580 * K) / 2, (H - 800 * K) / 2


def S(x, y):
    return round(OX + x * K), round(OY + y * K)


def px(v):
    return max(1, round(v * K))


CYAN = (0x00, 0xEE, 0xEE)
CYAN_DIM = (0x6F, 0xC0, 0xBA)
YELLOW = (0xFF, 0xCC, 0x00)
GREEN = (0x00, 0xAA, 0x00)
DARK_LINE = (0x1B, 0x2F, 0x2D)
HEADER_LINE = (0x1D, 0x2C, 0x33)
WHITE = (0xFF, 0xFF, 0xFF)


def font_file(pattern):
    return subprocess.check_output(["fc-match", "-f", "%{file}", pattern], text=True)


INCONSOLATA = font_file("Inconsolata")
INCONSOLATA_BOLD = font_file("Inconsolata:bold")
TERMINATOR = os.path.join(ROOT, "sddm-theme", "terminator.ttf")


def font(size, bold=False):
    return ImageFont.truetype(INCONSOLATA_BOLD if bold else INCONSOLATA, px(size))


def rich(draw, xy, parts, size, bold=False, anchor="lm"):
    """Draws [(text, color), ...] left to right (or ending at x with anchor "rm")."""
    f = font(size, bold)
    x, y = xy
    if anchor == "rm":
        x -= sum(draw.textlength(t, font=f) for t, _ in parts)
    for text, color in parts:
        draw.text((x, y), text, font=f, fill=color, anchor="lm")
        x += draw.textlength(text, font=f)


def header_bar(draw, x, y, width, left, right=None):
    """.lt-header: two thin lines with text between them (HeaderBar.qml)."""
    x0, y0 = S(x, y)
    x1, y1 = S(x + width, y + 18)
    draw.line([(x0, y0), (x1, y0)], fill=HEADER_LINE, width=1)
    draw.line([(x0, y1 - 1), (x1, y1 - 1)], fill=HEADER_LINE, width=1)
    rich(draw, (x0 + px(3), (y0 + y1) // 2), left, 11)
    if right:
        rich(draw, (x1 - px(3), (y0 + y1) // 2), right, 11, anchor="rm")


def panel(draw, x, y, width, height, title, title_right):
    """.content-container (Panel.qml); returns the body's stage origin and size."""
    draw.rounded_rectangle([S(x, y), S(x + width, y + height)], radius=px(2), outline=CYAN_DIM, width=px(2))
    ix, iy = x + 5, y + 5
    iw, ih = width - 10, height - 10
    draw.rectangle([S(ix, iy), S(ix + iw, iy + ih)], outline=DARK_LINE, width=1)
    tx, ty = S(ix + 4, iy + 12)
    rich(draw, (tx, ty), title, 16, bold=True)
    rx, _ = S(ix + iw - 4, iy + 12)
    rich(draw, (rx, ty), title_right, 13, bold=True, anchor="rm")
    lx0, ly = S(ix, iy + 24)
    lx1, _ = S(ix + iw, iy + 24)
    draw.line([(lx0, ly), (lx1, ly)], fill=DARK_LINE, width=1)
    return ix, iy + 25, iw, ih - 25


def badge(text_size=26):
    """The DANI-IDEAS badge of the splash screen, and its glow."""
    f = ImageFont.truetype(TERMINATOR, px(text_size))
    probe = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
    l, t, r, b = probe.textbbox((0, 0), "DANI-IDEAS", font=f)
    border, pad_x, pad_y = px(4), px(10), px(6)
    w = (r - l) + 2 * (pad_x + border)
    h = (b - t) + 2 * (pad_y + border)
    margin = px(20)   # room for the glow
    img = Image.new("RGBA", (w + 2 * margin, h + 2 * margin), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([margin, margin, margin + w - 1, margin + h - 1], radius=px(8),
                        outline=CYAN_DIM, width=border)
    d.text((margin + border + pad_x - l, margin + border + pad_y - t), "DANI-IDEAS", font=f, fill=CYAN_DIM)
    # box-shadow / text-shadow in #ccc
    alpha = img.getchannel("A").filter(ImageFilter.GaussianBlur(px(8)))
    glow = Image.new("RGBA", img.size, (0xCC, 0xCC, 0xCC, 0))
    glow.putalpha(alpha.point(lambda a: min(255, a * 2)))
    return img, glow


def main():
    os.makedirs(OUT, exist_ok=True)
    bg = Image.new("RGB", (W, H), "black")
    d = ImageDraw.Draw(bg)

    # #lt-container-outside / -inside
    d.rounded_rectangle([S(18, 18), S(1562, 782)], radius=px(5), outline=CYAN_DIM, width=px(2))
    d.rounded_rectangle([S(38, 23), S(1542, 777)], radius=px(5), outline=CYAN_DIM, width=px(2))

    # the merged column starts at (92, 25) and is 1328 wide
    cx, cy, cw = 92, 25, 1328
    header_bar(d, cx, cy + 25, cw,
               [("Plymouth LOGIN TERMINAL APP ", WHITE), ("OS", CYAN), ("26.1.2", YELLOW),
                (" ... MANJARO ... ", WHITE), ("LAUNCH LINUX GLOBALIZATION", CYAN)],
               [("OIA | 012", WHITE)])

    bx, by, bw, bh = panel(d, cx, cy + 60, cw, 398,
                           [("DANI-IDEAS OS12 ... SYSTEM ", WHITE), (".SEQUENCE", CYAN)],
                           [("END. PROGRAM", CYAN)])
    # terminal (Terminal.qml at x 10, y 20 in the panel body, 48% wide)
    term_x, term_y, term_w = bx + 10, by + 20, bw * 0.48
    hx, hy = S(term_x, term_y + 7)
    rich(d, (hx, hy), [("ENCOM OS12 BOOT CONSOLE ... tty1", WHITE)], 11)
    dash_y = S(0, term_y + 16)[1]
    x = S(term_x, 0)[0]
    while x < S(term_x + term_w, 0)[0]:
        d.line([(x, dash_y), (x + px(4), dash_y)], fill=WHITE, width=1)
        x += px(7)

    # badge on the right half of the panel
    badge_img, glow_img = badge()
    badge_cx, badge_cy = S(bx + bw * 0.54 - 12 + bw * 0.46 / 2, by + bh / 2 - 10)

    px2, py2, pw2, ph2 = panel(d, cx, cy + 490, cw, 188,
                               [("BOOT PROGRESS ", WHITE), (".GENERAL", CYAN)],
                               [("DATALINK: ", CYAN), ("CONNECTED.", GREEN)])
    # progress bar box with 10% ticks
    bar_x, bar_y, bar_w, bar_h = px2 + 10, py2 + 60, pw2 - 20, 22
    d.rectangle([S(bar_x, bar_y), S(bar_x + bar_w, bar_y + bar_h)], outline=CYAN_DIM, width=1)
    for i in range(11):
        tx, ty = S(bar_x + bar_w * i / 10, bar_y + bar_h + 6)
        d.line([(tx, ty), (tx, ty + px(6))], fill=DARK_LINE if 0 < i < 10 else CYAN_DIM, width=1)
        rich(d, (tx - px(6), ty + px(16)), [(f"{i * 10}", DARK_LINE if 0 < i < 10 else CYAN_DIM)], 9)
    fill = Image.new("RGB", (S(bar_x + bar_w, 0)[0] - S(bar_x, 0)[0] - 4, px(bar_h) - 4), CYAN_DIM)

    header_bar(d, cx, cy + 700, cw, [("DOCKING CHANNEL", WHITE)])
    fx, fy = S(cx + cw, cy + 709)
    for w, color, gap in ((35, CYAN_DIM, 0), (30, DARK_LINE, 8), (35, CYAN_DIM, 8)):
        fx -= px(gap)
        d.rounded_rectangle([fx - px(w), fy - px(3), fx, fy + px(3)], radius=px(2), outline=color, width=1)
        fx -= px(w)

    # far right column: logo
    lf = ImageFont.truetype(TERMINATOR, px(11))
    lx, ly = S(1440 + 20, 25 + 35)
    text_w = max(d.textlength(s, font=lf) for s in ("DANI-", "IDEAS"))
    d.rounded_rectangle([lx, ly, lx + text_w + px(8), ly + px(34)], radius=px(4), outline=CYAN_DIM, width=px(2))
    d.rectangle([lx + text_w + px(6), ly + px(4), lx + text_w + px(9), ly + px(30)], fill="black")
    d.text((lx + px(4), ly + px(3)), "DANI-\nIDEAS", font=lf, fill=CYAN_DIM, spacing=px(2))

    thumb = Image.open(os.path.join(ROOT, "images", "thumbprint.png")).convert("RGBA")
    thumb = thumb.resize((px(thumb.width), px(thumb.height)), Image.LANCZOS)
    thumb_x, thumb_y = S(1440 + 15, 25 + 630)

    bg.save(os.path.join(OUT, "background.png"))
    badge_img.save(os.path.join(OUT, "badge.png"))
    glow_img.save(os.path.join(OUT, "badge-glow.png"))
    thumb.save(os.path.join(OUT, "thumbprint.png"))
    fill.save(os.path.join(OUT, "bar-fill.png"))
    Image.new("RGB", (px(8), px(15)), CYAN).save(os.path.join(OUT, "cursor.png"))

    line_h = px(19)
    tx0, ty0 = S(term_x, term_y + 24)
    layout = {
        "DESIGN_W": W,
        "DESIGN_H": H,
        "TERM_X": tx0,
        "TERM_Y": ty0,
        "TERM_INDENT": px(25),
        "TERM_LINE_H": line_h,
        "TERM_ROWS": int((px(300) - px(24)) / line_h),
        "BADGE_X": badge_cx - badge_img.width // 2,
        "BADGE_Y": badge_cy - badge_img.height // 2,
        "STATUS_X": S(bar_x, 0)[0],
        "STATUS_Y": S(0, py2 + 30)[1],
        "PERCENT_X": S(bar_x + bar_w, 0)[0],
        "BAR_X": S(bar_x, 0)[0] + 2,
        "BAR_Y": S(0, bar_y)[1] + 2,
        "THUMB_X": thumb_x,
        "THUMB_Y": thumb_y,
    }
    with open(os.path.join(HERE, NAME + ".script.in")) as f:
        script = f.read()
    for key, value in layout.items():
        script = script.replace("@" + key + "@", str(value))
    with open(os.path.join(OUT, NAME + ".script"), "w") as f:
        f.write(script)
    shutil.copy(os.path.join(HERE, NAME + ".plymouth"), OUT)
    print("Tema listo en plymouth-theme/build/")


if __name__ == "__main__":
    main()
