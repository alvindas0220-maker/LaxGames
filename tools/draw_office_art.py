"""Dibuja el arte de la oficina con el estilo del héroe: bloques limpios y paleta plana.

Uso: python tools/draw_office_art.py

Salidas:
  assets/sprites/world/office_tiles.png  9 tiles de 16x16 en fila
  assets/sprites/world/office_props.png  4 equipos de 16x16 en fila
  assets/sprites/npc/npcs.png            4 NPC de 32x32: 6 columnas y 4 filas cada uno
  assets/sprites/npc/portraits/*.png     retratos de 32x32 y uno genérico
  assets/sprites/ui/warning_icons.png    2 iconos de 8x8 en fila
  assets/sprites/ui/tool_icons.png       3 iconos de 12x12 en fila
  assets/fonts/hud_pixel.png y .fnt      fuente con acentos y puntuación
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import draw_hero_pixels as hero

ROOT = Path(__file__).resolve().parent.parent
rgb = hero.rgb
INK = rgb("1a1420")
CLEAR = (0, 0, 0, 0)


def canvas(width, height, color=CLEAR):
    return [[color] * width for _ in range(height)]


def rect(pixels, x, y, w, h, color):
    for j in range(y, y + h):
        for i in range(x, x + w):
            pixels[j][i] = color


def dots(pixels, x0, color, points):
    for x, y in points:
        pixels[y][x0 + x] = color


def office_tiles():
    tiles = canvas(16 * 9, 16)
    # 0 moqueta de oficina, 1 pasillo, 2 sala de servidores, 3 RR. HH.
    rect(tiles, 0, 0, 16, 16, rgb("5c6a7e"))
    dots(tiles, 0, rgb("526074"), [(3, 4), (11, 2), (7, 11), (13, 13)])
    rect(tiles, 16, 0, 16, 16, rgb("b8b2a4"))
    rect(tiles, 16, 15, 16, 1, rgb("a29c8e"))
    rect(tiles, 31, 0, 1, 16, rgb("a29c8e"))
    rect(tiles, 32, 0, 16, 16, rgb("3c4656"))
    rect(tiles, 32, 7, 16, 1, rgb("323b4a"))
    rect(tiles, 39, 0, 1, 16, rgb("323b4a"))
    rect(tiles, 48, 0, 16, 16, rgb("7c5e58"))
    dots(tiles, 48, rgb("70544e"), [(4, 3), (12, 6), (6, 12), (14, 14)])
    # 4 pared
    rect(tiles, 64, 0, 16, 16, rgb("d8d2c4"))
    rect(tiles, 64, 0, 16, 4, rgb("3a3644"))
    rect(tiles, 64, 4, 16, 1, INK)
    rect(tiles, 64, 14, 16, 2, rgb("a8a294"))
    # 5 escritorio
    rect(tiles, 80, 0, 16, 16, rgb("5c6a7e"))
    rect(tiles, 80, 2, 16, 11, INK)
    rect(tiles, 81, 3, 14, 7, rgb("a87a4c"))
    rect(tiles, 81, 10, 14, 2, rgb("7c5636"))
    # 6 rack de servidores
    rect(tiles, 96, 0, 16, 16, rgb("3c4656"))
    rect(tiles, 97, 1, 14, 14, INK)
    rect(tiles, 98, 2, 12, 12, rgb("2c3038"))
    for y in (3, 6, 9, 12):
        rect(tiles, 99, y, 10, 1, rgb("4c5462"))
        tiles[y][107] = rgb("50e080")
    # 7 planta
    rect(tiles, 112, 0, 16, 16, rgb("5c6a7e"))
    rect(tiles, 116, 2, 8, 7, rgb("2e7a4a"))
    rect(tiles, 115, 4, 10, 3, rgb("2e7a4a"))
    rect(tiles, 118, 3, 3, 2, rgb("4aa468"))
    rect(tiles, 117, 9, 6, 5, rgb("a0583c"))
    rect(tiles, 117, 13, 6, 1, rgb("7c4430"))
    # 8 tapa de pared, para los muros que no muestran su cara
    rect(tiles, 128, 0, 16, 16, rgb("3a3644"))
    hero.write_png(ROOT / "assets/sprites/world/office_tiles.png", tiles)


def office_props():
    props = canvas(16 * 4, 16)
    # 0 PC
    rect(props, 2, 3, 12, 9, INK)
    rect(props, 3, 4, 10, 7, rgb("6ec8f0"))
    rect(props, 7, 12, 2, 2, INK)
    rect(props, 4, 14, 8, 1, INK)
    # 1 impresora
    rect(props, 17, 5, 14, 9, INK)
    rect(props, 18, 6, 12, 7, rgb("d8d8e0"))
    rect(props, 20, 3, 8, 3, rgb("f4f4f8"))
    rect(props, 20, 9, 8, 1, INK)
    # 2 router
    rect(props, 34, 9, 12, 5, INK)
    rect(props, 35, 10, 10, 3, rgb("3c4656"))
    rect(props, 36, 4, 1, 5, INK)
    rect(props, 43, 4, 1, 5, INK)
    props[11][38] = rgb("50e080")
    props[11][40] = rgb("50e080")
    # 3 proyector
    rect(props, 50, 6, 12, 7, INK)
    rect(props, 51, 7, 10, 5, rgb("c8c8d4"))
    rect(props, 53, 8, 4, 3, rgb("3c4656"))
    hero.write_png(ROOT / "assets/sprites/world/office_props.png", props)


def npc_sheet():
    looks = [
        {"T": rgb("b83a4a"), "t": rgb("8e2a3a"), "H": rgb("5a3420"), "j": rgb("7c4a2c")},
        {"T": rgb("3f8a5c"), "t": rgb("2e6a46"), "H": rgb("c89a4c"), "j": rgb("e0b868")},
        {"T": rgb("6a4aa0"), "t": rgb("50367e"), "H": rgb("8c8c98"), "j": rgb("a8a8b4")},
        {"T": rgb("2a8a94"), "t": rgb("1e6a72"), "H": rgb("9a3c28"), "j": rgb("bc5438")},
    ]
    sheet = canvas(32 * 6, 32 * 4 * len(looks))
    palette = hero.PALETTE
    for index, look in enumerate(looks):
        swap = {palette[key]: value for key, value in look.items()}
        for row, direction in enumerate(("down", "right", "up", "left")):
            view = "right" if direction == "left" else direction
            for col, grid in enumerate(hero.movement(view)):
                if direction == "left":
                    grid = hero.mirrored(grid)
                top = (index * 4 + row) * 32
                for y in range(32):
                    for x in range(32):
                        sheet[top + y][col * 32 + x] = swap.get(grid[y][x], grid[y][x])
    hero.write_png(ROOT / "assets/sprites/npc/npcs.png", sheet)


BUST = [
    "................................",
    "..........KKKKKKKKKKKK..........",
    "........KKHHHHHHHHHHHHKK........",
    ".......KHHHHHHHHHHHHHHHHK.......",
    "......KHHHHHHHHHHHHHHHHHHK......",
    "......KHHHHHHHHHHHHHHHHHHK......",
    ".....KHHHHSSSSSSSSSSSSHHHHK.....",
    ".....KHHHSSSSSSSSSSSSSSHHHK.....",
    ".....KHHSSSSSSSSSSSSSSSSHHK.....",
    ".....KHHSSbbbSSSSSSbbbSSHHK.....",
    ".....KHSSSSSSSSSSSSSSSSSSHK.....",
    ".....KHSSSweeSSSSSSeewSSSHK.....",
    ".....KHSSSweeSSSSSSeewSSSHK.....",
    ".....KSSSSSSSSSssSSSSSSSSSK.....",
    ".....KSSSSSSSSSssSSSSSSSSSK.....",
    ".....KSSSSSSSSSSSSSSSSSSSSK.....",
    "......KSSSSSSMMMMMMSSSSSSK......",
    "......KsSSSSSSSSSSSSSSSSsK......",
    ".......KssSSSSSSSSSSSSssK.......",
    ".........KKssSSSSSSssKK.........",
    "...........KSSSSSSSSK...........",
    "...........KsSSSSSSsK...........",
    "......KKKKKTTWWWWWWTTKKKKK......",
    "....KKTTTTTTTWWWWWWTTTTTTTKK....",
    "...KTTTTTTTTTWWWWWWTTTTTTTTTK...",
    "..KTTTTtTTTTTTWWWWTTTTTTtTTTTK..",
    ".KTTTTTtTTTTTTTWWTTTTTTTtTTTTTK.",
    ".KTTTTTtTTTTTTTttTTTTTTTtTTTTTK.",
    ".KTTTTTtTTTTTTTttTTTTTTTtTTTTTK.",
    ".KTTTTTtTTTTTTTttTTTTTTTtTTTTTK.",
    ".KTTTTTtTTTTTTTttTTTTTTTtTTTTTK.",
    ".KTTTTTtTTTTTTTttTTTTTTTtTTTTTK.",
]
# Colores de cada retrato: cabello, traje, sombra del traje, piel y si lleva melena.
PORTRAITS = {
    "alex": ("2c2c40", "24386e", "18264e", "f0c098", False),
    "ana": ("5a3420", "b83a4a", "8e2a3a", "f0c098", True),
    "bruno": ("c89a4c", "3f8a5c", "2e6a46", "e8b48c", False),
    "clara": ("8c8c98", "6a4aa0", "50367e", "f4ccae", True),
    "rrhh": ("9a3c28", "2a8a94", "1e6a72", "e8b48c", True),
    "generic": ("5c5660", "6a7284", "505868", "e0b090", False),
}


def portrait(hair, suit, suit_shade, skin, long_hair, curly=False):
    colors = {
        "K": INK, "H": rgb(hair), "S": rgb(skin), "s": rgb("cc8e6a"),
        "b": rgb("2a1e24"), "e": rgb("16161f"), "w": rgb("ffffff"), "M": rgb("b0604e"),
        "T": rgb(suit), "t": rgb(suit_shade), "W": rgb("f4f4f8"), ".": CLEAR,
    }
    rows = [list(line) for line in BUST]
    if curly:
        # Rizos: reflejos alternos y mechones sobre la frente.
        colors["j"] = rgb("56567a")
        for y, offset in ((2, 0), (3, 2), (4, 0), (5, 2)):
            for x in range(8 + offset, 25, 4):
                rows[y][x] = "j"
                rows[y][x + 1] = "j"
        for x in (11, 12, 16, 17, 20, 21):
            rows[6][x] = "H"
    if long_hair:
        for y in range(10, 24):
            for x in (3, 4, 5, 26, 27, 28):
                rows[y][x] = "H"
            rows[y][2] = "K"
            rows[y][29] = "K"
    for line in BUST:
        assert len(line) == 32, line
    return [[colors[ch] for ch in row] for row in rows]


def portraits():
    for name, (hair, suit, shade, skin, long_hair) in PORTRAITS.items():
        hero.write_png(ROOT / f"assets/sprites/npc/portraits/{name}.png", portrait(hair, suit, shade, skin, long_hair, name == "alex"))


def warning_icons():
    icons = canvas(16, 8)
    # 0 expediente limpio, 1 amonestación
    rect(icons, 1, 0, 6, 8, INK)
    rect(icons, 2, 1, 4, 6, rgb("3c4656"))
    rect(icons, 9, 0, 6, 8, INK)
    rect(icons, 10, 1, 4, 6, rgb("e8483c"))
    rect(icons, 11, 2, 2, 2, rgb("fff4a8"))
    icons[5][11] = rgb("fff4a8")
    icons[5][12] = rgb("fff4a8")
    hero.write_png(ROOT / "assets/sprites/ui/warning_icons.png", icons)


def tool_icons():
    icons = canvas(36, 12)
    # 0 destornillador del kit de herramientas
    rect(icons, 3, 0, 6, 7, INK)
    rect(icons, 4, 1, 4, 5, rgb("e0b040"))
    rect(icons, 5, 1, 1, 5, rgb("f8d878"))
    rect(icons, 4, 7, 4, 4, INK)
    rect(icons, 5, 7, 2, 3, rgb("c8d4e0"))
    rect(icons, 5, 11, 2, 1, INK)
    # 1 café reparador
    rect(icons, 13, 4, 8, 7, INK)
    rect(icons, 14, 5, 6, 5, rgb("f4f4f8"))
    rect(icons, 14, 5, 6, 2, rgb("6a3c20"))
    rect(icons, 21, 5, 2, 1, INK)
    rect(icons, 22, 5, 1, 4, INK)
    rect(icons, 21, 8, 2, 1, INK)
    rect(icons, 15, 1, 1, 2, rgb("c8d4e0"))
    rect(icons, 18, 0, 1, 3, rgb("c8d4e0"))
    # 2 memoria USB de diagnóstico
    rect(icons, 27, 4, 7, 7, INK)
    rect(icons, 28, 5, 5, 5, rgb("2c6ad0"))
    rect(icons, 29, 6, 1, 1, rgb("50e080"))
    rect(icons, 28, 1, 5, 3, INK)
    rect(icons, 29, 2, 3, 2, rgb("c8d4e0"))
    hero.write_png(ROOT / "assets/sprites/ui/tool_icons.png", icons)


GLYPHS = {
    "A": "25755", "B": "65656", "C": "34443", "D": "65556", "E": "74647", "F": "74644",
    "G": "34553", "H": "55755", "I": "72227", "J": "11152", "K": "55655", "L": "44447",
    "M": "57755", "N": "65555", "O": "25552", "P": "65644", "Q": "25573", "R": "65655",
    "S": "34216", "T": "72222", "U": "55557", "V": "55552", "W": "55775", "X": "55255",
    "Y": "55222", "Z": "71247", "0": "75557", "1": "26227", "2": "61247", "3": "61216",
    "4": "55711", "5": "74616", "6": "34757", "7": "71222", "8": "75757", "9": "75716",
    ".": "00002", ",": "00024", ":": "02020", "!": "22202", "?": "61202", "%": "51245",
    "/": "11244", "-": "00700", "(": "24442", ")": "42224", "'": "22000", "+": "02720",
    '"': "55000", "[": "64446", "]": "31113", "¿": "20243", "¡": "20222", ">": "42124",
}
# Minúsculas y acentos comparten el glifo de su mayúscula.
ALIASES = {"Á": "A", "É": "E", "Í": "I", "Ó": "O", "Ú": "U", "Ü": "U", "Ñ": "N"}


def hud_font():
    chars = list(GLYPHS)
    image = canvas(len(chars) * 4, 6)
    white = (255, 255, 255, 255)
    for index, char in enumerate(chars):
        for y, code in enumerate(GLYPHS[char]):
            bits = int(code)
            for x in range(3):
                if bits & (4 >> x):
                    image[y][index * 4 + x] = white
    hero.write_png(ROOT / "assets/fonts/hud_pixel.png", image)
    entries = {" ": None}
    for index, char in enumerate(chars):
        entries[char] = index
    for char, base in ALIASES.items():
        entries[char] = chars.index(base)
    for char in [c for c in chars if c.isalpha()] + list(ALIASES):
        entries[char.lower()] = entries[char]
    lines = [
        'info face="HudPixel" size=6 bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=0 padding=0,0,0,0 spacing=1,1 outline=0',
        f"common lineHeight=7 base=5 scaleW={len(image[0])} scaleH=6 pages=1 packed=0",
        'page id=0 file="hud_pixel.png"',
        f"chars count={len(entries)}",
    ]
    for char, index in entries.items():
        if index is None:
            lines.append(f"char id={ord(char)} x=0 y=0 width=0 height=0 xoffset=0 yoffset=0 xadvance=4 page=0 chnl=15")
        else:
            lines.append(f"char id={ord(char)} x={index * 4} y=0 width=3 height=5 xoffset=0 yoffset=0 xadvance=4 page=0 chnl=15")
    (ROOT / "assets/fonts/hud_pixel.fnt").write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    office_tiles()
    office_props()
    npc_sheet()
    portraits()
    warning_icons()
    tool_icons()
    hud_font()
    print("arte de oficina generado")
