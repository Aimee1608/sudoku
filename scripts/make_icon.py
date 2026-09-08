#!/usr/bin/env python3
"""生成 App 图标。设计语言沿用彩虹跳跳棋:深色底 + 极淡的结构剪影 + 高饱和主体带发光。
跳跳棋的主体是六角星上的彩色棋子,数独换成九宫格里的彩色数字。

    python3 scripts/make_icon.py Sources/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
"""
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

S = 1024
FONT = "/home/jiangqian.8/.local/share/fonts/NotoSansCJKsc-VF.otf"
FONT_FALLBACK = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def load_font(size):
    try:
        f = ImageFont.truetype(FONT, size)
        f.set_variation_by_name("Black")
        return f
    except Exception:
        return ImageFont.truetype(FONT_FALLBACK, size)

BG_CENTER = (18, 66, 96)
BG_EDGE = (6, 24, 40)
BOX_LINE = (45, 212, 191)

# 深海探险主题的提亮数字色,对角 + 中心五格
CELLS = {
    0: ("5", (116, 214, 234)),
    2: ("2", (255, 178, 115)),
    4: ("9", (253, 224, 71)),
    6: ("3", (255, 128, 113)),
    8: ("7", (198, 161, 242)),
}


def background():
    ramp = Image.radial_gradient("L").resize((S, S), Image.LANCZOS)
    img = Image.new("RGB", (S, S))
    px = img.load()
    rp = ramp.load()
    for y in range(S):
        for x in range(S):
            t = rp[x, y] / 255.0
            px[x, y] = tuple(
                int(BG_CENTER[i] + (BG_EDGE[i] - BG_CENTER[i]) * t) for i in range(3)
            )
    return img.convert("RGBA")


def faint_grid(img):
    """铺满画布的 9×9 网格剪影,对应跳跳棋背景里那个几乎看不见的六角星。"""
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    span = S * 0.86
    origin = (S - span) / 2
    step = span / 9
    for i in range(10):
        p = origin + step * i
        wide = 3 if i % 3 == 0 else 2
        alpha = 15 if i % 3 == 0 else 8
        d.line([(p, origin), (p, origin + span)], fill=(255, 255, 255, alpha), width=wide)
        d.line([(origin, p), (origin + span, p)], fill=(255, 255, 255, alpha), width=wide)
    img.alpha_composite(layer)


def board(img):
    span = 640
    origin = (S - span) / 2
    step = span / 3

    plate = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(plate)
    d.rounded_rectangle(
        [origin - 22, origin - 22, origin + span + 22, origin + span + 22],
        radius=50, fill=(255, 255, 255, 18),
    )
    img.alpha_composite(plate)

    tiles = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    dt = ImageDraw.Draw(tiles)
    for idx in range(9):
        r, c = divmod(idx, 3)
        x0 = origin + c * step
        y0 = origin + r * step
        pad = 10
        rect = [x0 + pad, y0 + pad, x0 + step - pad, y0 + step - pad]
        if idx in CELLS:
            tint = CELLS[idx][1]
            dt.rounded_rectangle(rect, radius=22, fill=tint + (34,),
                                 outline=tint + (90,), width=4)
        else:
            dt.rounded_rectangle(rect, radius=22, fill=(255, 255, 255, 10))
    img.alpha_composite(tiles)

    lines = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    dl = ImageDraw.Draw(lines)
    for i in range(1, 3):
        p = origin + step * i
        dl.line([(p, origin), (p, origin + span)], fill=(255, 255, 255, 60), width=5)
        dl.line([(origin, p), (origin + span, p)], fill=(255, 255, 255, 60), width=5)
    dl.rounded_rectangle(
        [origin, origin, origin + span, origin + span],
        radius=30, outline=BOX_LINE + (225,), width=9,
    )
    img.alpha_composite(lines)
    return origin, step


def digits(img, origin, step):
    font = load_font(168)
    ink = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    di = ImageDraw.Draw(ink)
    for idx, (text, color) in CELLS.items():
        r, c = divmod(idx, 3)
        cx = origin + c * step + step / 2
        cy = origin + r * step + step / 2
        box = di.textbbox((0, 0), text, font=font)
        di.text(
            (cx - (box[0] + box[2]) / 2, cy - (box[1] + box[3]) / 2),
            text, font=font, fill=color + (255,),
        )
    # 先把数字层糊开当色光,再压清晰的一层上去——跟跳跳棋棋子的外发光是同一手法。
    # 两层不同半径:大的铺氛围,小的贴着字缘提亮
    wide = ink.filter(ImageFilter.GaussianBlur(46))
    wide.putalpha(wide.getchannel("A").point(lambda a: min(255, int(a * 1.5))))
    img.alpha_composite(wide)
    tight = ink.filter(ImageFilter.GaussianBlur(16))
    tight.putalpha(tight.getchannel("A").point(lambda a: min(255, int(a * 1.3))))
    img.alpha_composite(tight)
    img.alpha_composite(ink)


def vignette(img):
    ramp = Image.radial_gradient("L").resize((S, S), Image.LANCZOS)
    shade = Image.new("RGBA", (S, S), (0, 0, 0, 255))
    shade.putalpha(ramp.point(lambda v: int(v * 0.30)))
    img.alpha_composite(shade)


def main(out):
    img = background()
    faint_grid(img)
    vignette(img)
    origin, step = board(img)
    digits(img, origin, step)
    img.convert("RGB").save(out, "PNG")
    print("wrote", out)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "AppIcon-1024.png")
