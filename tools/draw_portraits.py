"""Retratos de 40x40 con sombreado por rampas de color: frente con luz desde la izquierda.

Cada personaje combina peinado, ropa, tono de piel y accesorios. El contorno
se calcula al final alrededor de la silueta.

Uso: python tools/draw_portraits.py
Salida: assets/sprites/npc/portraits/*.png
"""

from pathlib import Path

import draw_hero_pixels as hero

ROOT = Path(__file__).resolve().parent.parent
SIZE = 40
rgb = hero.rgb
INK = rgb("1a1420")
CLEAR = (0, 0, 0, 0)

SKINS = {
    "clara": ("ffdcbc", "f0c098", "d09a78", "a87458"),
    "media": ("f0c8a0", "dca680", "b88860", "8e6444"),
    "morena": ("dca680", "c08c68", "98684c", "744c38"),
}
EYES = {"oscuro": "3a2418", "azul": "2c6ad0", "verde": "2e7a4a", "miel": "8a5a24"}

# nombre: peinado, (pelo claro, base, oscuro), (ropa clara, base, oscura), ropa, piel, ojos, extras
PEOPLE = {
    "alex": ("rizado", ("56567a", "2c2c40", "16161f"), ("3a5494", "24386e", "18264e"), "traje", "clara", "oscuro", ()),
    "alex_f": ("larga", ("643e50", "3a2430", "24141c"), ("3a5494", "24386e", "18264e"), "traje", "clara", "oscuro", ("aretes",)),
    "ana": ("media", ("8a5a34", "5a3420", "3e2214"), ("d85a68", "b83a4a", "8e2a3a"), "blusa", "clara", "miel", ("aretes",)),
    "bruno": ("corto", ("e0b868", "c89a4c", "a07a34"), ("56a874", "3f8a5c", "2e6a46"), "camisa", "media", "verde", ()),
    "clara": ("mono", ("b0b0bc", "8c8c98", "686874"), ("8a68c0", "6a4aa0", "50367e"), "traje", "clara", "azul", ("aretes",)),
    "rrhh": ("media", ("c85a3c", "9a3c28", "74281c"), ("3caab4", "2a8a94", "1e6a72"), "blusa", "media", "verde", ()),
    "diego": ("corto", ("443844", "2a2028", "16121a"), ("e09a48", "c47a2c", "9a5c1e"), "camisa", "morena", "oscuro", ("cascos",)),
    "ivan": ("raya", ("88643f", "6a4a30", "4c3420"), ("727c8a", "56606e", "404854"), "camisa", "clara", "oscuro", ("gafas",)),
    "lucia": ("larga", ("54344c", "30202c", "1c1218"), ("e46aa4", "c84a86", "9c3468"), "blusa", "media", "miel", ("aretes",)),
    "tomas": ("revuelto", ("e8cc90", "d0b070", "a88a50"), ("98b84e", "7a9a3c", "5c7a2c"), "camisa", "clara", "azul", ("gafas",)),
    "sofia": ("mono", ("d8d8e0", "b8b8c4", "90909c"), ("383c48", "20242e", "14161e"), "traje", "media", "oscuro", ("gafas", "aretes")),
    "ramon": ("rapado", ("544848", "3a3030", "241c1c"), ("3e5078", "2a3a5c", "1c2840"), "uniforme", "morena", "oscuro", ()),
    "elena": ("mono", ("9c7a54", "7c5a3c", "5c4028"), ("68c0c0", "48a0a0", "347c7c"), "camisa", "clara", "miel", ()),
    "pablo": ("gorra", ("404050", "24242c", "14141a"), ("f0bc40", "d8a020", "a87c18"), "uniforme", "media", "oscuro", ()),
    "nadia": ("media", ("c87c48", "a85c30", "804222"), ("f08c78", "e06c58", "b45444"), "blusa", "clara", "verde", ("cascos",)),
    "carla": ("mono", ("383848", "1c1c28", "101018"), ("ffffff", "f0f0f4", "c8c8d4"), "camisa", "morena", "oscuro", ("aretes",)),
    "hugo": ("calvo", ("e0e0e8", "c8c8d0", "a0a0ac"), ("684078", "4c2c5c", "382044"), "traje", "media", "oscuro", ("gafas",)),
    "ines": ("larga", ("f0d088", "e0b868", "b89048"), ("c83454", "a01c3c", "7c142c"), "traje", "clara", "azul", ("aretes",)),
    "generic": ("corto", ("7c7680", "5c5660", "403c44"), ("868ea0", "6a7284", "505868"), "camisa", "media", "oscuro", ()),
}


class Canvas:
    def __init__(self):
        self.px = [[CLEAR] * SIZE for _ in range(SIZE)]

    def put(self, x, y, color):
        if 0 <= x < SIZE and 0 <= y < SIZE:
            self.px[y][x] = color

    def rect(self, x, y, w, h, color):
        for j in range(y, y + h):
            for i in range(x, x + w):
                self.put(i, j, color)

    def ellipse(self, cx, cy, rx, ry, color, keep=None):
        """Elipse rellena; keep filtra qué píxeles se pintan."""
        for y in range(SIZE):
            for x in range(SIZE):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1 and (keep is None or keep(x, y)):
                    self.put(x, y, color)


def torso(c, cloth, skin, kind):
    light, base, dark = cloth
    c.ellipse(19.5, 45, 19.5, 15, base)
    c.ellipse(19.5, 45, 19.5, 15, dark, lambda x, y: x > 30 or y > 37)
    c.ellipse(19.5, 45, 19.5, 15, light, lambda x, y: x < 7 and y < 37)
    c.rect(16, 29, 8, 6, skin[1])
    c.rect(16, 29, 8, 2, skin[2])
    c.rect(22, 29, 2, 6, skin[2])
    shirt = rgb("f4f4f8")
    shade = rgb("c8c8d4")
    if kind == "traje":
        for y in range(32, 40):
            half = max(1, 5 - (y - 32) // 2)
            c.rect(20 - half, y, half * 2, 1, shirt)
            c.put(19 - half, y, dark)
            c.put(20 + half, y, dark)
            c.put(18 - half, y, light)
        c.rect(19, 36, 2, 4, shade)
    elif kind == "camisa":
        for y in range(32, 35):
            c.put(15 - (y - 32), y, light)
            c.put(24 + (y - 32), y, dark)
            c.rect(16 - (y - 32) // 2, y, 1, 1, light)
        c.rect(19, 35, 1, 5, dark)
        c.put(19, 36, light)
        c.put(19, 38, light)
    elif kind == "blusa":
        for y in range(32, 37):
            half = max(0, 4 - (y - 32))
            c.rect(20 - half, y, half * 2, 1, skin[1])
        c.rect(14, 33, 2, 1, light)
        c.rect(24, 33, 2, 1, dark)
    elif kind == "uniforme":
        c.rect(15, 32, 10, 2, dark)
        c.rect(19, 34, 2, 6, dark)
        c.rect(11, 36, 3, 3, rgb("e8c84a"))
        c.put(12, 37, rgb("a08020"))
        c.rect(26, 36, 4, 1, light)


def face(c, skin, eye):
    light, base, shade, deep = skin
    # Cráneo y mandíbula: la barbilla se estrecha desde la altura de la boca.
    c.ellipse(19.5, 16, 11, 12, base)
    c.ellipse(19.5, 21, 9, 9, base)
    c.ellipse(19.5, 16, 11, 12, light, lambda x, y: x < 15 and y < 17)
    c.ellipse(19.5, 16, 11, 12, shade, lambda x, y: x > 27)
    c.ellipse(19.5, 21, 9, 9, shade, lambda x, y: x > 26 or y > 28)
    # Orejas
    c.rect(7, 15, 2, 5, base)
    c.put(8, 16, shade)
    c.rect(31, 15, 2, 5, shade)
    c.put(31, 16, deep)
    # Ojos
    iris = rgb(EYES[eye])
    for x0 in (12, 23):
        c.rect(x0, 16, 5, 3, rgb("ffffff"))
        c.rect(x0 + 1, 16, 3, 3, iris)
        c.rect(x0 + 2, 17, 1, 2, rgb("10101a"))
        c.put(x0 + 1, 16, rgb("ffffff"))
        c.rect(x0, 15, 5, 1, INK)
        c.put(x0 - 1, 16, INK if x0 == 12 else base)
        c.put(x0 + 5, 16, INK if x0 == 23 else base)
        c.rect(x0, 19, 5, 1, shade)
    # Nariz
    c.rect(20, 18, 1, 4, shade)
    c.rect(19, 22, 3, 1, shade)
    c.put(19, 20, light)
    # Boca y mejillas
    c.rect(17, 25, 6, 1, deep)
    c.rect(18, 26, 4, 1, shade)
    c.rect(11, 22, 3, 1, shade)
    c.rect(26, 22, 3, 1, shade)


def brows(c, color):
    c.rect(12, 13, 5, 1, color)
    c.rect(23, 13, 5, 1, color)
    c.put(11, 14, color)
    c.put(28, 14, color)


def hair_back(c, style, hair):
    light, base, dark = hair
    if style == "larga":
        c.ellipse(19.5, 15, 13, 13, base)
        c.rect(6, 15, 28, 19, base)
        c.rect(6, 26, 3, 9, dark)
        c.rect(31, 15, 3, 20, dark)
        c.rect(7, 16, 1, 12, light)
    elif style == "media":
        c.ellipse(19.5, 15, 13, 13, base)
        c.rect(6, 15, 28, 12, base)
        c.rect(31, 15, 3, 12, dark)
        c.rect(7, 16, 1, 8, light)
    elif style == "mono":
        c.ellipse(19.5, 2, 5, 4, base)
        c.ellipse(18.5, 1, 3, 2, light)


def hair_front(c, style, hair):
    light, base, dark = hair

    def cap(limit, color=base):
        c.ellipse(19.5, 13, 12, 11, color, lambda x, y: y < limit)

    def shine(y, x0=11, width=9):
        c.rect(x0, y, width, 1, light)
        c.rect(x0 + 2, y + 1, width - 5, 1, light)

    if style == "rizado":
        cap(11)
        for x, y in ((9, 8), (13, 5), (18, 3), (23, 4), (28, 7), (31, 11), (7, 12), (12, 10), (17, 9), (22, 9), (27, 11)):
            c.ellipse(x, y, 3.2, 3.2, base)
        for x, y in ((9, 7), (13, 4), (18, 2), (23, 3), (12, 9), (17, 8), (22, 8)):
            c.rect(x - 1, y - 1, 2, 1, light)
        for x, y in ((29, 9), (31, 12), (27, 12)):
            c.rect(x, y, 2, 1, dark)
    elif style == "corto":
        cap(10)
        c.rect(8, 8, 2, 7, base)
        c.rect(30, 8, 2, 7, dark)
        for x in (11, 15, 19, 23, 27):
            c.rect(x, 10, 3, 1, base)
        shine(4)
    elif style == "raya":
        cap(10)
        c.rect(8, 8, 2, 6, base)
        c.rect(30, 8, 2, 6, dark)
        for x in range(13, 30):
            c.put(x, 10 + (x - 13) // 8, base)
            c.put(x, 11 + (x - 13) // 8, base)
        c.rect(13, 3, 1, 8, dark)
        shine(4, 15, 9)
    elif style == "revuelto":
        cap(9)
        for x, y in ((10, 4), (15, 2), (21, 1), (27, 4), (30, 8)):
            c.rect(x, y, 3, 4, base)
            c.put(x + 1, y, light)
        for x in (10, 14, 19, 24, 28):
            c.rect(x, 9, 2, 2, base)
        shine(5, 12, 7)
    elif style == "larga":
        cap(10)
        c.rect(19, 3, 1, 8, dark)
        for y in range(10, 18):
            c.rect(8, y, max(1, 4 - (y - 10) // 2), 1, base)
            c.rect(32 - max(1, 4 - (y - 10) // 2), y, max(1, 4 - (y - 10) // 2), 1, dark)
        shine(4, 11, 7)
        c.rect(23, 5, 5, 1, light)
    elif style == "media":
        cap(10)
        c.rect(18, 3, 1, 7, dark)
        for y in range(10, 16):
            c.rect(8, y, 2, 1, base)
            c.rect(30, y, 2, 1, dark)
        shine(4, 11, 6)
    elif style == "mono":
        cap(10)
        c.rect(8, 9, 2, 5, base)
        c.rect(30, 9, 2, 5, dark)
        shine(4)
    elif style == "rapado":
        cap(7, dark)
        c.rect(12, 3, 16, 1, base)
    elif style == "gorra":
        cap(9, dark)
        c.ellipse(19.5, 8, 12, 7, dark, lambda x, y: y < 10)
        c.rect(7, 9, 26, 2, base)
        c.rect(9, 9, 14, 1, light)
        c.rect(16, 3, 8, 4, base)
    elif style == "calvo":
        c.ellipse(19.5, 12, 11, 9, base, lambda x, y: (x < 11 or x > 28) and 7 < y < 16)
        c.rect(8, 9, 2, 6, light)
        c.rect(30, 9, 2, 6, dark)


def extras(c, items, skin):
    if "gafas" in items:
        frame = rgb("50586a")
        for x0 in (11, 22):
            c.rect(x0, 14, 7, 1, frame)
            c.rect(x0, 19, 7, 1, frame)
            c.rect(x0, 14, 1, 6, frame)
            c.rect(x0 + 6, 14, 1, 6, frame)
        c.rect(18, 15, 4, 1, frame)
    if "aretes" in items:
        c.rect(7, 21, 2, 2, rgb("e8c84a"))
        c.rect(31, 21, 2, 2, rgb("e8c84a"))
    if "cascos" in items:
        band = rgb("50586a")
        for x in range(9, 31):
            c.put(x, 3 if 13 <= x <= 26 else 4, band)
        c.rect(7, 5, 2, 9, band)
        c.rect(31, 5, 2, 9, band)
        c.rect(5, 13, 4, 8, band)
        c.rect(6, 14, 2, 6, rgb("2c3038"))
        c.rect(31, 13, 4, 8, band)
        c.rect(8, 25, 9, 1, band)
        c.rect(7, 21, 1, 5, band)
        c.rect(16, 24, 2, 2, rgb("2c3038"))


def outline(c):
    original = [row[:] for row in c.px]
    for y in range(SIZE):
        for x in range(SIZE):
            if original[y][x][3] != 0:
                continue
            around = [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]
            if any(0 <= i < SIZE and 0 <= j < SIZE and original[j][i][3] != 0 for i, j in around):
                c.px[y][x] = INK


def portrait(style, hair, cloth, kind, skin_name, eye, items):
    c = Canvas()
    hair_rgb = tuple(rgb(v) for v in hair)
    cloth_rgb = tuple(rgb(v) for v in cloth)
    skin = tuple(rgb(v) for v in SKINS[skin_name])
    hair_back(c, style, hair_rgb)
    torso(c, cloth_rgb, skin, kind)
    face(c, skin, eye)
    hair_front(c, style, hair_rgb)
    brows(c, hair_rgb[2] if style != "calvo" else hair_rgb[2])
    extras(c, items, skin)
    outline(c)
    return c.px


def main():
    for name, spec in PEOPLE.items():
        hero.write_png(ROOT / f"assets/sprites/npc/portraits/{name}.png", portrait(*spec))


if __name__ == "__main__":
    main()
