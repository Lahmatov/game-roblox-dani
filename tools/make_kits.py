"""Рисует шаблоны одежды Roblox (Shirt и Pants, 585x559) для футбольных форм.

Дизайн по картинке Дани: зелёно-белые полосы со львом, красная с золотыми
полосками и звездой, чёрная с фиолетовой лентой, золотая с короной.

Запуск:  python3 tools/make_kits.py
Результат: assets/kits/<kit>_shirt.png, <kit>_pants.png и preview.png
"""

import math
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

S = 4  # рисуем в 4 раза крупнее, потом уменьшаем — так края получаются гладкими
W, H = 585, 559
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "kits")
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

# Разметка официального шаблона Roblox (x, y, ширина, высота)
TORSO = {
    "front": (231, 74, 128, 128),
    "back": (427, 74, 128, 128),
    "left": (165, 74, 64, 128),
    "right": (361, 74, 64, 128),
    "up": (231, 8, 128, 64),
    "down": (231, 204, 128, 64),
}
RIGHT_LIMB = {
    "up": (217, 289, 64, 64),
    "down": (217, 485, 64, 64),
    "left": (19, 355, 64, 128),
    "back": (85, 355, 64, 128),
    "right": (151, 355, 64, 128),
    "front": (217, 355, 64, 128),
}
LEFT_LIMB = {
    "up": (308, 289, 64, 64),
    "down": (308, 485, 64, 64),
    "front": (308, 355, 64, 128),
    "left": (374, 355, 64, 128),
    "back": (440, 355, 64, 128),
    "right": (506, 355, 64, 128),
}

SLEEVE = 46  # короткий рукав: сколько пикселей руки закрыто (из 128)
SHORTS = 52  # шорты на ноге
SOCKS = 70  # отсюда начинаются гетры
BOOTS = 112  # отсюда бутсы


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) for i in (0, 2, 4)) + (255,)


def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c[:3]) + (c[3],)


KITS = {
    "lions": {
        "name": "Зелёные львы",
        "number": "7",
        "pattern": "hoops",
        "a": rgb("#0b8a45"),
        "b": rgb("#ffffff"),
        "trim": rgb("#ffffff"),
        "emblem": "lion",
        "num_fill": rgb("#ffffff"),
        "num_edge": rgb("#0b6b37"),
        "shorts": rgb("#ffffff"),
        "shorts_trim": rgb("#0b8a45"),
        "socks": rgb("#0b8a45"),
        "socks_band": rgb("#ffffff"),
    },
    "stars": {
        "name": "Красные звёзды",
        "number": "10",
        "pattern": "pinstripes",
        "a": rgb("#d32222"),
        "b": rgb("#f2b630"),
        "trim": rgb("#f2b630"),
        "emblem": "star",
        "num_fill": rgb("#f7c548"),
        "num_edge": rgb("#8f1414"),
        "shorts": rgb("#b51b1b"),
        "shorts_trim": rgb("#f2b630"),
        "socks": rgb("#d32222"),
        "socks_band": rgb("#f2b630"),
    },
    "night": {
        "name": "Ночная молния",
        "number": "9",
        "pattern": "sash",
        "a": rgb("#1c1c22"),
        "b": rgb("#9b30ff"),
        "trim": rgb("#9b30ff"),
        "emblem": "bolt",
        "num_fill": rgb("#b25cff"),
        "num_edge": rgb("#2a0a4a"),
        "shorts": rgb("#1c1c22"),
        "shorts_trim": rgb("#9b30ff"),
        "socks": rgb("#1c1c22"),
        "socks_band": rgb("#9b30ff"),
    },
    "gold": {
        "name": "Золотая",
        "number": "1",
        "pattern": "gold",
        "a": rgb("#f5bf2a"),
        "b": rgb("#ffe27a"),
        "trim": rgb("#fff1b8"),
        "emblem": "crown",
        "num_fill": rgb("#fff6d5"),
        "num_edge": rgb("#b8860b"),
        "shorts": rgb("#eab220"),
        "shorts_trim": rgb("#fff1b8"),
        "socks": rgb("#f5bf2a"),
        "socks_band": rgb("#fff1b8"),
    },
}


# ---------------------------------------------------------------- узоры


def paint_pattern(img, kit, face):
    """Заливает грань узором. Координата y общая для всех граней тела, поэтому полосы сходятся."""
    d = ImageDraw.Draw(img)
    w, h = img.size
    a, b = kit["a"], kit["b"]
    d.rectangle([0, 0, w, h], fill=a)
    p = kit["pattern"]
    if p == "hoops":
        band = 16 * S
        for i, y in enumerate(range(0, h, band)):
            if i % 2 == 1:
                d.rectangle([0, y, w, y + band - 1], fill=b)
    elif p == "pinstripes":
        step, thick = 16 * S, 2 * S
        for x in range(step // 2, w, step):
            d.rectangle([x, 0, x + thick, h], fill=b)
    elif p == "sash" and face in ("front", "back"):
        t = 22 * S
        # Лента с правого плеча вниз налево (на спине — зеркально)
        if face == "front":
            poly = [(w - t * 1.6, 0), (w, 0), (w, t * 0.6), (t * 1.6, h), (0, h), (0, h - t * 0.6)]
        else:
            poly = [(0, 0), (t * 1.6, 0), (w, h - t * 0.6), (w, h), (w - t * 1.6, h), (0, t * 0.6)]
        d.polygon(poly, fill=b)
        # Неоновое свечение
        glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ImageDraw.Draw(glow).polygon(poly, outline=shade(b, 1.4), width=3 * S)
        img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(3 * S)))
    elif p == "gold":
        # Мягкий узор ромбами
        step = 24 * S
        for y in range(-step, h + step, step):
            for x in range(-step, w + step, step):
                off = step // 2 if (y // step) % 2 else 0
                cx = x + off
                d.polygon(
                    [(cx, y - step // 3), (cx + step // 3, y), (cx, y + step // 3), (cx - step // 3, y)],
                    outline=b,
                    width=2 * S,
                )


def add_shading(img, side=False):
    """Лёгкая объёмность: снизу и по краям чуть темнее, сверху блик."""
    w, h = img.size
    over = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    for y in range(h):
        t = y / h
        alpha = int(max(0, t - 0.6) * 90)
        d.line([(0, y), (w, y)], fill=(0, 0, 0, alpha))
    if side:
        d.rectangle([0, 0, w, h], fill=(0, 0, 0, 28))
    alpha = img.getchannel("A")
    img.alpha_composite(over)
    img.putalpha(alpha)  # тень только на ткани, прозрачное остаётся прозрачным


def star_points(cx, cy, r_out, r_in, n=5, rot=-math.pi / 2):
    pts = []
    for i in range(n * 2):
        r = r_out if i % 2 == 0 else r_in
        ang = rot + i * math.pi / n
        pts.append((cx + math.cos(ang) * r, cy + math.sin(ang) * r))
    return pts


def draw_emblem(img, kind, cx, cy, size):
    d = ImageDraw.Draw(img)
    s = size * S
    cx, cy = cx * S, cy * S
    gold, dark = rgb("#f2b630"), rgb("#7a5200")
    if kind == "lion":
        # Щит с головой льва
        shield = [(cx - s, cy - s), (cx + s, cy - s), (cx + s, cy + s * 0.2), (cx, cy + s * 1.2), (cx - s, cy + s * 0.2)]
        d.polygon(shield, fill=rgb("#0b6b37"), outline=gold, width=2 * S)
        d.polygon(star_points(cx, cy - s * 0.1, s * 0.75, s * 0.5, n=10), fill=rgb("#e09a1c"))
        d.ellipse([cx - s * 0.42, cy - s * 0.52, cx + s * 0.42, cy + s * 0.32], fill=gold)
        for ex in (-0.16, 0.16):
            d.ellipse([cx + s * ex - s * 0.06, cy - s * 0.24, cx + s * ex + s * 0.06, cy - s * 0.12], fill=dark)
        d.ellipse([cx - s * 0.09, cy - s * 0.02, cx + s * 0.09, cy + s * 0.1], fill=dark)
    elif kind == "star":
        d.polygon(star_points(cx, cy, s * 1.05, s * 0.45), fill=gold, outline=dark, width=S)
    elif kind == "bolt":
        d.ellipse([cx - s, cy - s, cx + s, cy + s], fill=rgb("#2a0a4a"), outline=rgb("#b25cff"), width=2 * S)
        bolt = [(cx + s * 0.15, cy - s * 0.75), (cx - s * 0.4, cy + s * 0.1), (cx - s * 0.02, cy + s * 0.1),
                (cx - s * 0.15, cy + s * 0.75), (cx + s * 0.4, cy - s * 0.15), (cx + s * 0.02, cy - s * 0.15)]
        d.polygon(bolt, fill=rgb("#d9a6ff"))
    elif kind == "crown":
        crown = [(cx - s, cy + s * 0.6), (cx - s, cy - s * 0.4), (cx - s * 0.5, cy + s * 0.05), (cx, cy - s * 0.8),
                 (cx + s * 0.5, cy + s * 0.05), (cx + s, cy - s * 0.4), (cx + s, cy + s * 0.6)]
        d.polygon(crown, fill=rgb("#fff1b8"), outline=dark, width=S)
        for px in (-1, 0, 1):
            r = s * 0.13
            x = cx + px * s * (1 if px else 0)
            y = cy - s * (0.4 if px else 0.8)
            d.ellipse([x - r, y - r, x + r, y + r], fill=rgb("#e53935"))


def draw_number(img, text, fill, edge, size):
    d = ImageDraw.Draw(img)
    font = ImageFont.truetype(FONT, size * S)
    w, h = img.size
    d.text((w / 2, h * 0.48), text, font=font, fill=fill, anchor="mm", stroke_width=4 * S, stroke_fill=edge)


def draw_collar(img, kit, face):
    d = ImageDraw.Draw(img)
    w, h = img.size
    trim = kit["trim"]
    if face == "front":
        d.arc([w * 0.34, -h * 0.12, w * 0.66, h * 0.12], 0, 180, fill=trim, width=4 * S)
    elif face == "back":
        d.rectangle([w * 0.3, 0, w * 0.7, 3 * S], fill=trim)
    elif face == "up":
        d.ellipse([w * 0.3, h * 0.25, w * 0.7, h * 0.95], outline=trim, width=4 * S)
    if face in ("front", "back", "left", "right"):
        d.rectangle([0, h - 4 * S, w, h], fill=shade(trim, 0.92))  # низ футболки


# ---------------------------------------------------------------- сборка шаблонов


def face_canvas(rect):
    _, _, w, h = rect
    return Image.new("RGBA", (w * S, h * S), (0, 0, 0, 0))


def paste(sheet, img, rect):
    x, y, _, _ = rect
    sheet.alpha_composite(img, (x * S, y * S))


def make_shirt(kit):
    sheet = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
    for face, rect in TORSO.items():
        img = face_canvas(rect)
        paint_pattern(img, kit, face)
        draw_collar(img, kit, face)
        if face == "front":
            draw_emblem(img, kit["emblem"], 90, 34, 12)
        if face == "back":
            draw_number(img, kit["number"], kit["num_fill"], kit["num_edge"], 64)
        add_shading(img, side=face in ("left", "right"))
        paste(sheet, img, rect)
    for limb in (RIGHT_LIMB, LEFT_LIMB):
        for face, rect in limb.items():
            img = face_canvas(rect)
            if face == "down":
                continue  # кисть — без ткани
            paint_pattern(img, kit, face)
            if face != "up":
                w, h = img.size
                cut = SLEEVE * S
                d = ImageDraw.Draw(img)
                d.rectangle([0, cut - 5 * S, w, cut], fill=kit["trim"])  # манжета
                d.rectangle([0, cut, w, h], fill=(0, 0, 0, 0))  # дальше рука без рукава
                add_shading(img, side=face in ("left", "right"))
            paste(sheet, img, rect)
    return sheet.resize((W, H), Image.LANCZOS)


def make_pants(kit):
    sheet = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
    shorts, trim = kit["shorts"], kit["shorts_trim"]
    for face, rect in TORSO.items():
        img = face_canvas(rect)
        d = ImageDraw.Draw(img)
        w, h = img.size
        d.rectangle([0, 0, w, h], fill=shorts)
        if face in ("left", "right"):
            d.rectangle([w * 0.42, 0, w * 0.58, h], fill=trim)
        add_shading(img, side=face in ("left", "right"))
        paste(sheet, img, rect)
    for limb in (RIGHT_LIMB, LEFT_LIMB):
        for face, rect in limb.items():
            img = face_canvas(rect)
            d = ImageDraw.Draw(img)
            w, h = img.size
            if face == "up":
                d.rectangle([0, 0, w, h], fill=shorts)
            elif face == "down":
                d.rectangle([0, 0, w, h], fill=rgb("#2b2b30"))  # подошва
            else:
                d.rectangle([0, 0, w, SHORTS * S], fill=shorts)
                if face in ("left", "right"):
                    d.rectangle([w * 0.4, 0, w * 0.6, SHORTS * S], fill=trim)
                d.rectangle([0, (SHORTS - 4) * S, w, SHORTS * S], fill=shade(shorts, 0.85))
                d.rectangle([0, SOCKS * S, w, BOOTS * S], fill=kit["socks"])
                d.rectangle([0, (SOCKS + 6) * S, w, (SOCKS + 12) * S], fill=kit["socks_band"])
                d.rectangle([0, BOOTS * S, w, h], fill=rgb("#2b2b30"))
                d.rectangle([0, (BOOTS + 9) * S, w, (BOOTS + 11) * S], fill=rgb("#f5f5f5"))
                add_shading(img, side=face in ("left", "right"))
            paste(sheet, img, rect)
    return sheet.resize((W, H), Image.LANCZOS)


# ---------------------------------------------------------------- превью


def crop(sheet, rect):
    x, y, w, h = rect
    return sheet.crop((x, y, x + w, y + h))


def figure(shirt, pants, view, skin=rgb("#f5cd30")):
    """Собирает персонажа (вид спереди или сзади) из граней шаблона — так он выглядит в игре."""
    fig = Image.new("RGBA", (256, 332), (0, 0, 0, 0))
    d = ImageDraw.Draw(fig)
    d.rounded_rectangle([96, 8, 160, 70], radius=14, fill=skin, outline=shade(skin, 0.75), width=2)
    if view == "front":
        d.ellipse([110, 28, 118, 36], fill=(30, 30, 30, 255))
        d.ellipse([138, 28, 146, 36], fill=(30, 30, 30, 255))
        d.arc([112, 34, 144, 58], 20, 160, fill=(30, 30, 30, 255), width=3)
    near = RIGHT_LIMB if view == "front" else LEFT_LIMB  # левая сторона картинки
    far = LEFT_LIMB if view == "front" else RIGHT_LIMB
    for x, limb in ((0, near), (192, far)):  # руки
        d.rectangle([x + 1, 72, x + 63, 199], fill=skin)
        fig.alpha_composite(crop(shirt, limb[view]), (x, 72))
    for x, limb in ((64, near), (128, far)):  # ноги
        d.rectangle([x + 1, 200, x + 63, 327], fill=skin)
        fig.alpha_composite(crop(pants, limb[view]), (x, 200))
    fig.alpha_composite(crop(pants, TORSO[view]), (64, 72))
    fig.alpha_composite(crop(shirt, TORSO[view]), (64, 72))
    return fig


def make_preview(sheets):
    cols = len(sheets)
    card_w, card_h = 300, 420
    img = Image.new("RGBA", (cols * card_w + 40, card_h * 2 + 120), rgb("#0e1626"))
    d = ImageDraw.Draw(img)
    title = ImageFont.truetype(FONT, 34)
    font = ImageFont.truetype(FONT, 24)
    small = ImageFont.truetype(FONT, 18)
    d.text((img.width / 2, 40), "Формы по дизайну Дани — так они будут выглядеть в игре", font=title, fill=rgb("#ffd23c"), anchor="mm")
    for i, (key, (shirt, pants)) in enumerate(sheets.items()):
        x0 = 20 + i * card_w
        for row, view in enumerate(("front", "back")):
            y0 = 80 + row * (card_h + 10)
            d.rounded_rectangle([x0 + 8, y0, x0 + card_w - 8, y0 + card_h], radius=18, fill=rgb("#1d5e38"))
            fig = figure(shirt, pants, view)
            img.alpha_composite(fig, (x0 + (card_w - 256) // 2, y0 + 20))
            label = KITS[key]["name"] if view == "front" else "сзади"
            d.text((x0 + card_w / 2, y0 + card_h - 40), label, font=font if view == "front" else small, fill=(255, 255, 255, 255), anchor="mm")
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    sheets = {}
    for key, kit in KITS.items():
        shirt = make_shirt(kit)
        pants = make_pants(kit)
        shirt.save(os.path.join(OUT, f"{key}_shirt.png"))
        pants.save(os.path.join(OUT, f"{key}_pants.png"))
        sheets[key] = (shirt, pants)
        print("готово:", kit["name"])
    make_preview(sheets).convert("RGB").save(os.path.join(OUT, "preview.png"))
    print("превью:", os.path.join(OUT, "preview.png"))


if __name__ == "__main__":
    main()
