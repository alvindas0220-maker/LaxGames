"""Dibuja el arte de la oficina con el estilo del héroe: bloques limpios y paleta plana.

Uso: python tools/draw_office_art.py

Salidas:
  assets/sprites/world/office_tiles.png  48 tiles de 16x16 en 3 filas
  assets/sprites/world/office_props.png  12 equipos de 16x16 en fila
  assets/sprites/npc/npcs.png            16 NPC de 32x32: 6 columnas y 4 filas cada uno
  assets/sprites/ui/warning_icons.png    2 iconos de 8x8 en fila
  assets/sprites/ui/tool_icons.png       4 iconos de 12x12 en fila
"""

import random
import struct
import sys
import zlib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import draw_hero_pixels as hero
import draw_portraits
import draw_ui_font

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


def shifted(color, amount):
    return tuple(max(0, min(255, c + amount)) for c in color[:3]) + (color[3],)


def polish(tiles, x0, y0, contact_shadow=True):
    """Da volumen a un objeto: luz en el borde superior, sombra abajo y al apoyar en el suelo."""
    source = [[tiles[y0 + y][x0 + x] for x in range(16)] for y in range(16)]

    def solid(x, y):
        return 0 <= x < 16 and 0 <= y < 16 and source[y][x][3] == 255 and source[y][x] != INK

    for y in range(16):
        for x in range(16):
            if not solid(x, y):
                continue
            if not solid(x, y - 1):
                tiles[y0 + y][x0 + x] = shifted(source[y][x], 26)
            elif not solid(x, y + 1) or not solid(x + 1, y):
                tiles[y0 + y][x0 + x] = shifted(source[y][x], -24)
    if contact_shadow:
        for x in range(16):
            bottom = max((y for y in range(16) if source[y][x][3] != 0), default=-1)
            for depth, alpha in ((1, 88), (2, 44)):
                if bottom >= 0 and bottom + depth < 16:
                    tiles[y0 + bottom + depth][x0 + x] = (16, 12, 28, alpha)


def texture(tiles, x0, y0, seed, spread=6, count=34):
    """Grano fino para que ningún suelo sea un color plano. Mantiene el borde repetible."""
    rng = random.Random(seed)
    for _ in range(count):
        x, y = rng.randrange(16), rng.randrange(16)
        tiles[y0 + y][x0 + x] = shifted(tiles[y0 + y][x0 + x], rng.choice((-spread, spread)))


def sheen(tiles, x0, y0):
    """Reflejo diagonal de suelo pulido."""
    for offset in range(0, 3):
        for y in range(16):
            x = (11 - y + offset) % 16
            if tiles[y0 + y][x0 + x][3] == 255:
                tiles[y0 + y][x0 + x] = shifted(tiles[y0 + y][x0 + x], 9)


def desk(tiles, x, y=0, top="a87a4c", light="c49660", front="7c5636"):
    """Escritorio con fondo transparente: deja ver el suelo de cada sala."""
    rect(tiles, x, y + 2, 16, 11, INK)
    rect(tiles, x + 1, y + 3, 14, 7, rgb(top))
    rect(tiles, x + 1, y + 3, 14, 1, rgb(light))
    rect(tiles, x + 1, y + 10, 14, 2, rgb(front))
    rect(tiles, x + 2, y + 13, 2, 2, INK)
    rect(tiles, x + 12, y + 13, 2, 2, INK)


def rack(tiles, x, y, lit):
    rect(tiles, x, y, 16, 16, rgb("3c4656"))
    rect(tiles, x + 1, y + 1, 14, 14, INK)
    rect(tiles, x + 2, y + 2, 12, 12, rgb("2c3038"))
    for index, row in enumerate((3, 6, 9, 12)):
        rect(tiles, x + 3, y + row, 10, 1, rgb("4c5462"))
        on = (index + lit) % 2 == 0
        tiles[y + row][x + 11] = rgb("50e080") if on else rgb("1e5a3c")
        tiles[y + row][x + 9] = rgb("7a5c28") if on else rgb("e8b048")


def wall_base(tiles, x, y):
    rect(tiles, x, y, 16, 16, rgb("d8d2c4"))
    rect(tiles, x, y, 16, 4, rgb("3a3644"))
    rect(tiles, x, y + 4, 16, 1, INK)
    rect(tiles, x, y + 5, 16, 1, rgb("ece6d8"))
    rect(tiles, x, y + 12, 16, 1, rgb("8c8678"))
    rect(tiles, x, y + 13, 16, 3, rgb("6c6e7c"))
    rect(tiles, x, y + 15, 16, 1, rgb("4c4e5c"))


def furniture(tiles):
    """Fila 1 y 2 del atlas: suelos de las salas nuevas, mobiliario y detalles."""
    def at(index):
        return (index % 16) * 16, (index // 16) * 16

    # 16 cafetería: baldosa ajedrezada
    x, y = at(16)
    rect(tiles, x, y, 16, 16, rgb("d8cdb0"))
    rect(tiles, x, y, 8, 8, rgb("b89a70"))
    rect(tiles, x + 8, y + 8, 8, 8, rgb("b89a70"))
    # 17 baño: gresite claro
    x, y = at(17)
    rect(tiles, x, y, 16, 16, rgb("c4dce0"))
    for n in (3, 7, 11, 15):
        rect(tiles, x, y + n, 16, 1, rgb("a4c0c8"))
        rect(tiles, x + n, y, 1, 16, rgb("a4c0c8"))
    # 18 gerencia: parqué en espiga claro
    x, y = at(18)
    rect(tiles, x, y, 16, 16, rgb("b08850"))
    for n in range(0, 16, 4):
        rect(tiles, x, y + n, 8, 1, rgb("98743f"))
        rect(tiles, x + 8, y + (n + 2) % 16, 8, 1, rgb("98743f"))
    rect(tiles, x + 7, y, 1, 16, rgb("98743f"))
    rect(tiles, x + 15, y, 1, 16, rgb("98743f"))
    dots(tiles, x, rgb("c4a068"), [(2, y + 2), (11, y + 5), (5, y + 10), (13, y + 13)])
    # 19 panel de cubículo horizontal
    x, y = at(19)
    rect(tiles, x, y + 2, 16, 11, INK)
    rect(tiles, x, y + 3, 16, 2, rgb("c8ccd4"))
    rect(tiles, x, y + 5, 16, 7, rgb("6a7a94"))
    for n in (2, 6, 10, 14):
        tiles[y + 7][x + n] = rgb("5a6a84")
        tiles[y + 10][x + (n + 2) % 16] = rgb("5a6a84")
    # 20 panel de cubículo vertical
    x, y = at(20)
    rect(tiles, x + 5, y, 6, 15, INK)
    rect(tiles, x + 6, y, 4, 14, rgb("c8ccd4"))
    rect(tiles, x + 7, y, 2, 14, rgb("6a7a94"))
    # 21 esquina de cubículo
    x, y = at(21)
    rect(tiles, x + 3, y + 2, 10, 11, INK)
    rect(tiles, x + 4, y + 3, 8, 3, rgb("c8ccd4"))
    rect(tiles, x + 4, y + 6, 8, 6, rgb("6a7a94"))
    # 22 silla de oficina vista por detrás
    x, y = at(22)
    rect(tiles, x + 4, y + 2, 8, 8, INK)
    rect(tiles, x + 5, y + 3, 6, 6, rgb("3c4656"))
    rect(tiles, x + 5, y + 3, 6, 1, rgb("566274"))
    rect(tiles, x + 7, y + 10, 2, 2, INK)
    rect(tiles, x + 4, y + 12, 8, 1, INK)
    # 23 fotocopiadora
    x, y = at(23)
    rect(tiles, x + 1, y + 2, 14, 13, INK)
    rect(tiles, x + 2, y + 3, 12, 11, rgb("d8d8e0"))
    rect(tiles, x + 3, y + 4, 8, 2, rgb("3c4656"))
    rect(tiles, x + 12, y + 4, 1, 1, rgb("50e080"))
    rect(tiles, x + 3, y + 8, 10, 1, rgb("a0a0ac"))
    rect(tiles, x + 3, y + 11, 10, 1, rgb("a0a0ac"))
    # 24 fuente de agua
    x, y = at(24)
    rect(tiles, x + 4, y, 8, 8, INK)
    rect(tiles, x + 5, y + 1, 6, 6, rgb("8cd0f0"))
    rect(tiles, x + 5, y + 1, 2, 3, rgb("c8ecfc"))
    rect(tiles, x + 3, y + 8, 10, 7, INK)
    rect(tiles, x + 4, y + 9, 8, 5, rgb("e8e8f0"))
    tiles[y + 10][x + 6] = rgb("e8483c")
    tiles[y + 10][x + 9] = rgb("2c6ad0")
    # 25 máquina expendedora
    x, y = at(25)
    rect(tiles, x + 1, y, 14, 15, INK)
    rect(tiles, x + 2, y + 1, 12, 13, rgb("b83a4a"))
    rect(tiles, x + 3, y + 2, 7, 9, rgb("24283a"))
    for row in (3, 6, 9):
        dots(tiles, x, rgb("e8b048"), [(4, y + row), (8, y + row)])
        dots(tiles, x, rgb("50e080"), [(6, y + row)])
    rect(tiles, x + 11, y + 3, 2, 4, rgb("c8c8d4"))
    rect(tiles, x + 3, y + 12, 7, 1, INK)
    # 26 barra con cafetera
    x, y = at(26)
    rect(tiles, x, y + 2, 16, 13, INK)
    rect(tiles, x, y + 3, 16, 7, rgb("c8ccd4"))
    rect(tiles, x, y + 10, 16, 4, rgb("7c5636"))
    rect(tiles, x + 4, y, 8, 8, INK)
    rect(tiles, x + 5, y + 1, 6, 6, rgb("50586a"))
    rect(tiles, x + 6, y + 2, 4, 1, rgb("e8483c"))
    rect(tiles, x + 7, y + 4, 2, 2, rgb("f4f4f8"))
    # 27 barra
    x, y = at(27)
    rect(tiles, x, y + 2, 16, 13, INK)
    rect(tiles, x, y + 3, 16, 7, rgb("c8ccd4"))
    rect(tiles, x, y + 4, 16, 1, rgb("e4e8ec"))
    rect(tiles, x, y + 10, 16, 4, rgb("7c5636"))
    # 28 mesa de comedor con bandeja
    x, y = at(28)
    rect(tiles, x, y + 3, 16, 10, INK)
    rect(tiles, x + 1, y + 4, 14, 6, rgb("e8e0c8"))
    rect(tiles, x + 1, y + 10, 14, 2, rgb("a8a088"))
    rect(tiles, x + 5, y + 5, 6, 3, rgb("f4f4f8"))
    rect(tiles, x + 7, y + 6, 2, 1, rgb("e8483c"))
    # 29 sofá
    x, y = at(29)
    rect(tiles, x, y + 2, 16, 13, INK)
    rect(tiles, x + 1, y + 3, 14, 5, rgb("3f8a5c"))
    rect(tiles, x + 1, y + 8, 14, 5, rgb("56a874"))
    rect(tiles, x + 8, y + 8, 1, 5, rgb("3f8a5c"))
    # 30 cubículo de baño
    x, y = at(30)
    rect(tiles, x, y, 16, 15, INK)
    rect(tiles, x + 1, y, 14, 14, rgb("9cb0bc"))
    rect(tiles, x + 5, y + 3, 6, 9, INK)
    rect(tiles, x + 6, y + 4, 4, 7, rgb("f4f4f8"))
    rect(tiles, x + 7, y + 5, 2, 3, rgb("c4dce0"))
    # 31 lavabo con espejo
    x, y = at(31)
    rect(tiles, x + 3, y, 10, 6, INK)
    rect(tiles, x + 4, y + 1, 8, 4, rgb("c8ecfc"))
    rect(tiles, x + 5, y + 1, 2, 2, rgb("f4f4f8"))
    rect(tiles, x + 2, y + 7, 12, 6, INK)
    rect(tiles, x + 3, y + 8, 10, 4, rgb("f4f4f8"))
    rect(tiles, x + 5, y + 9, 6, 2, rgb("c4dce0"))
    rect(tiles, x + 7, y + 7, 2, 2, rgb("8c94a0"))
    # 32 pared con pizarra
    x, y = at(32)
    wall_base(tiles, x, y)
    rect(tiles, x + 1, y + 6, 14, 6, INK)
    rect(tiles, x + 2, y + 7, 12, 4, rgb("f4f4f8"))
    rect(tiles, x + 3, y + 8, 5, 1, rgb("2c6ad0"))
    rect(tiles, x + 9, y + 9, 3, 1, rgb("e8483c"))
    # 33 pared con cartel
    x, y = at(33)
    wall_base(tiles, x, y)
    rect(tiles, x + 4, y + 5, 8, 7, INK)
    rect(tiles, x + 5, y + 6, 6, 5, rgb("e8b048"))
    rect(tiles, x + 6, y + 7, 4, 1, rgb("a03838"))
    rect(tiles, x + 6, y + 9, 3, 1, rgb("3c4656"))
    # 34 pared con reloj
    x, y = at(34)
    wall_base(tiles, x, y)
    rect(tiles, x + 5, y + 6, 6, 6, INK)
    rect(tiles, x + 6, y + 7, 4, 4, rgb("f4f4f8"))
    rect(tiles, x + 7, y + 8, 1, 2, INK)
    tiles[y + 9][x + 8] = INK
    # 35 estantería
    x, y = at(35)
    rect(tiles, x + 1, y, 14, 15, INK)
    rect(tiles, x + 2, y + 1, 12, 13, rgb("6a4a30"))
    for row in (1, 8):
        rect(tiles, x + 2, y + row + 5, 12, 1, INK)
        for col, color in ((3, "b83a4a"), (5, "2c6ad0"), (7, "e8b048"), (9, "3f8a5c"), (11, "c8c8d4")):
            rect(tiles, x + col, y + row + 1, 1, 4, rgb(color))
    # 36, 37 y 38 estación central con monitores
    for index, side in ((36, "left"), (37, "mid"), (38, "right")):
        x, y = at(index)
        rect(tiles, x, y + 5, 16, 10, INK)
        rect(tiles, x, y + 6, 16, 3, rgb("c8ccd4"))
        rect(tiles, x, y + 9, 16, 5, rgb("2c4a78"))
        rect(tiles, x, y + 10, 16, 1, rgb("3c6498"))
        if side == "left":
            rect(tiles, x, y + 5, 1, 10, INK)
        if side == "right":
            rect(tiles, x + 15, y + 5, 1, 10, INK)
        rect(tiles, x + 4, y, 8, 6, INK)
        rect(tiles, x + 5, y + 1, 6, 4, rgb("183c2c") if side == "mid" else rgb("6ec8f0"))
        rect(tiles, x + 6, y + 2, 3, 1, rgb("50e080") if side == "mid" else rgb("f4f4f8"))
    # 39 alfombra de sala
    x, y = at(39)
    rect(tiles, x, y, 16, 16, rgb("8e2a3a"))
    dots(tiles, x, rgb("a83c4c"), [(3, y + 3), (11, y + 3), (7, y + 7), (3, y + 11), (11, y + 11)])
    # 40 mesa de dirección con portátil
    x, y = at(40)
    desk(tiles, x, y, "5a3424", "74482f", "3e2418")
    rect(tiles, x + 5, y + 3, 6, 4, INK)
    rect(tiles, x + 6, y + 4, 4, 2, rgb("6ec8f0"))
    rect(tiles, x + 5, y + 7, 6, 2, rgb("8c94a0"))
    # 42 y 43 rack con luces parpadeantes (dos fotogramas)
    x, y = at(42)
    rack(tiles, x, y, 0)
    x, y = at(43)
    rack(tiles, x, y, 1)
    # 45 y 46 escritorio con monitor encendido, dos fotogramas
    for index, offset in ((45, 0), (46, 1)):
        x, y = at(index)
        desk(tiles, x, y)
        rect(tiles, x + 4, y, 8, 7, INK)
        rect(tiles, x + 5, y + 1, 6, 4, rgb("183c5c"))
        for row in range(3):
            rect(tiles, x + 6, y + 1 + (row + offset) % 4, 1 + (row * 3 + offset) % 4, 1, rgb("6ec8f0"))
        rect(tiles, x + 7, y + 7, 2, 1, INK)
        rect(tiles, x + 5, y + 8, 6, 1, rgb("2c3038"))
        rect(tiles, x + 13, y + 7, 2, 2, rgb("f4f4f8"))
    # 44 papelera
    x, y = at(44)
    rect(tiles, x + 5, y + 6, 6, 8, INK)
    rect(tiles, x + 6, y + 7, 4, 6, rgb("6c6e7c"))
    rect(tiles, x + 6, y + 7, 4, 1, rgb("f4f4f8"))


def office_tiles():
    tiles = canvas(16 * 16, 16 * 3)
    # 0 moqueta de Helpdesk: trama de dos tonos.
    rect(tiles, 0, 0, 16, 16, rgb("5c6a7e"))
    for y in range(0, 16, 4):
        for x in range(0, 16, 4):
            tiles[y + ((x // 4) % 2) * 2][x + 1] = rgb("566478")
            tiles[y + 2 - ((x // 4) % 2) * 2][x + 3] = rgb("627084")
    # 1 pasillo: baldosa grande con junta y brillo.
    rect(tiles, 16, 0, 16, 16, rgb("b8b2a4"))
    rect(tiles, 17, 1, 13, 1, rgb("c8c2b4"))
    rect(tiles, 17, 1, 1, 13, rgb("c8c2b4"))
    rect(tiles, 16, 15, 16, 1, rgb("9c9688"))
    rect(tiles, 31, 0, 1, 16, rgb("9c9688"))
    # 2 suelo técnico de servidores: placas con remaches.
    rect(tiles, 32, 0, 16, 16, rgb("3c4656"))
    rect(tiles, 32, 7, 16, 1, rgb("2e3644"))
    rect(tiles, 32, 15, 16, 1, rgb("2e3644"))
    rect(tiles, 39, 0, 1, 16, rgb("2e3644"))
    rect(tiles, 47, 0, 1, 16, rgb("2e3644"))
    dots(tiles, 32, rgb("566274"), [(1, 1), (5, 1), (9, 9), (13, 9), (9, 1), (13, 1), (1, 9), (5, 9)])
    # 3 RR. HH.: tarima de madera.
    rect(tiles, 48, 0, 16, 16, rgb("7c5e58"))
    for y, seam in ((3, 5), (7, 12), (11, 3), (15, 9)):
        rect(tiles, 48, y, 16, 1, rgb("664a44"))
        tiles[y - 2][48 + seam] = rgb("664a44")
        tiles[y - 1][48 + seam] = rgb("664a44")
    dots(tiles, 48, rgb("8c6e66"), [(2, 1), (10, 5), (6, 9), (13, 13)])
    # 4 pared con cornisa, zócalo y luz.
    rect(tiles, 64, 0, 16, 16, rgb("d8d2c4"))
    rect(tiles, 64, 0, 16, 4, rgb("3a3644"))
    rect(tiles, 64, 4, 16, 1, INK)
    rect(tiles, 64, 5, 16, 1, rgb("ece6d8"))
    rect(tiles, 64, 12, 16, 1, rgb("8c8678"))
    rect(tiles, 64, 13, 16, 3, rgb("6c6e7c"))
    rect(tiles, 64, 15, 16, 1, rgb("4c4e5c"))
    # 5 escritorio con papeles
    desk(tiles, 80)
    rect(tiles, 84, 4, 5, 4, rgb("f4f4f8"))
    rect(tiles, 85, 5, 3, 1, rgb("8c94a0"))
    rect(tiles, 91, 5, 2, 2, rgb("e8483c"))
    # 6 rack de servidores
    rect(tiles, 96, 0, 16, 16, rgb("3c4656"))
    rect(tiles, 97, 1, 14, 14, INK)
    rect(tiles, 98, 2, 12, 12, rgb("2c3038"))
    for y in (3, 6, 9, 12):
        rect(tiles, 99, y, 10, 1, rgb("4c5462"))
        tiles[y][107] = rgb("50e080")
        tiles[y][105] = rgb("e8b048")
    # 7 planta
    rect(tiles, 116, 2, 8, 7, rgb("2e7a4a"))
    rect(tiles, 115, 4, 10, 3, rgb("2e7a4a"))
    rect(tiles, 118, 3, 3, 2, rgb("4aa468"))
    rect(tiles, 122, 5, 2, 1, rgb("4aa468"))
    rect(tiles, 117, 9, 6, 5, rgb("a0583c"))
    rect(tiles, 117, 9, 6, 1, rgb("bc7450"))
    rect(tiles, 117, 13, 6, 1, rgb("7c4430"))
    # 8 tapa de pared, para los muros que no muestran su cara
    rect(tiles, 128, 0, 16, 16, rgb("3a3644"))
    # 9 Desarrollo: parqué oscuro.
    rect(tiles, 144, 0, 16, 16, rgb("4a4058"))
    for x, seam in ((3, 4), (7, 11), (11, 2), (15, 8)):
        rect(tiles, 144 + x, 0, 1, 16, rgb("3e3448"))
        tiles[seam][144 + x - 2] = rgb("3e3448")
    dots(tiles, 144, rgb("584e68"), [(1, 2), (5, 10), (9, 5), (13, 13)])
    # 10 Jefatura: alfombra con borde dorado.
    rect(tiles, 160, 0, 16, 16, rgb("3a5a5c"))
    dots(tiles, 160, rgb("446a6c"), [(2, 2), (6, 6), (10, 10), (14, 14), (10, 2), (14, 6), (2, 10), (6, 14)])
    dots(tiles, 160, rgb("c4a050"), [(0, 0), (8, 8)])
    # 11 escritorio con ordenador
    desk(tiles, 176)
    rect(tiles, 180, 0, 8, 7, INK)
    rect(tiles, 181, 1, 6, 4, rgb("6ec8f0"))
    rect(tiles, 182, 2, 3, 1, rgb("f4f4f8"))
    rect(tiles, 183, 7, 2, 1, INK)
    rect(tiles, 181, 8, 6, 1, rgb("2c3038"))
    rect(tiles, 189, 7, 2, 2, rgb("f4f4f8"))
    # 12 archivador
    rect(tiles, 194, 1, 12, 14, INK)
    rect(tiles, 195, 2, 10, 12, rgb("8c94a0"))
    for y in (2, 7):
        rect(tiles, 195, y + 4, 10, 1, rgb("5c6470"))
        rect(tiles, 198, y + 1, 4, 1, rgb("e8e4d8"))
        rect(tiles, 199, y + 3, 2, 1, rgb("2c3038"))
    # 13 pared con ventana
    rect(tiles, 208, 0, 16, 16, rgb("d8d2c4"))
    rect(tiles, 208, 0, 16, 4, rgb("3a3644"))
    rect(tiles, 208, 4, 16, 1, INK)
    rect(tiles, 210, 5, 12, 8, INK)
    rect(tiles, 211, 6, 10, 6, rgb("8cd0f0"))
    rect(tiles, 211, 6, 4, 2, rgb("c8ecfc"))
    rect(tiles, 215, 6, 1, 6, INK)
    rect(tiles, 208, 13, 16, 3, rgb("6c6e7c"))
    rect(tiles, 208, 15, 16, 1, rgb("4c4e5c"))
    # 14 sombra que proyecta una pared sobre el suelo
    for y, alpha in ((0, 96), (1, 72), (2, 48), (3, 24)):
        rect(tiles, 224, y, 16, 1, (16, 12, 28, alpha))
    furniture(tiles)
    for index, seed in ((0, 1), (3, 2), (9, 3), (10, 4), (16, 5), (18, 6), (2, 7)):
        texture(tiles, (index % 16) * 16, (index // 16) * 16, seed)
    for index in (1, 17):
        sheen(tiles, (index % 16) * 16, (index // 16) * 16)
    for index in (5, 7, 11, 12, 19, 21, 23, 24, 25, 26, 27, 28, 29, 31, 35, 36, 37, 38, 40, 44, 45, 46):
        polish(tiles, (index % 16) * 16, (index // 16) * 16)
    for index in (6, 22, 30, 42, 43):
        polish(tiles, (index % 16) * 16, (index // 16) * 16, False)
    hero.write_png(ROOT / "assets/sprites/world/office_tiles.png", tiles)


def office_props():
    props = canvas(16 * 12, 16)
    # 0 PC
    rect(props, 2, 3, 12, 9, INK)
    rect(props, 3, 4, 10, 7, rgb("6ec8f0"))
    rect(props, 4, 5, 5, 1, rgb("f4f4f8"))
    rect(props, 4, 7, 3, 1, rgb("3c8ab0"))
    rect(props, 7, 12, 2, 2, INK)
    rect(props, 4, 14, 8, 1, INK)
    # 1 impresora
    rect(props, 17, 5, 14, 9, INK)
    rect(props, 18, 6, 12, 7, rgb("d8d8e0"))
    rect(props, 20, 3, 8, 3, rgb("f4f4f8"))
    rect(props, 20, 9, 8, 1, INK)
    props[7][28] = rgb("50e080")
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
    props[8][59] = rgb("e8483c")
    # 4 switch de red con puertos y cables
    rect(props, 65, 6, 14, 7, INK)
    rect(props, 66, 7, 12, 5, rgb("4c5462"))
    for x in (67, 69, 71, 73, 75):
        props[9][x] = rgb("16161f")
        props[8][x] = rgb("50e080")
    rect(props, 67, 13, 1, 2, rgb("2c6ad0"))
    rect(props, 71, 13, 1, 2, rgb("e8b048"))
    rect(props, 75, 13, 1, 2, rgb("e8483c"))
    # 5 servidor de compilación
    rect(props, 83, 1, 10, 14, INK)
    rect(props, 84, 2, 8, 12, rgb("2c3038"))
    rect(props, 85, 3, 6, 3, rgb("183c2c"))
    rect(props, 86, 4, 3, 1, rgb("50e080"))
    rect(props, 85, 8, 6, 1, rgb("4c5462"))
    rect(props, 85, 10, 6, 1, rgb("4c5462"))
    props[12][86] = rgb("e8483c")
    props[12][88] = rgb("e8b048")
    # 6 rack RAID con bahías de disco
    rect(props, 97, 0, 14, 15, INK)
    rect(props, 98, 1, 12, 13, rgb("2c3038"))
    for y in (2, 5, 8, 11):
        for x in (99, 104):
            rect(props, x, y, 4, 2, rgb("566274"))
        props[y][102] = rgb("50e080")
    props[5][107] = rgb("e8b048")
    # 7 lector biométrico en pedestal
    rect(props, 116, 1, 8, 9, INK)
    rect(props, 117, 2, 6, 7, rgb("3c4656"))
    rect(props, 118, 3, 4, 2, rgb("6ec8f0"))
    rect(props, 118, 6, 4, 2, rgb("c8d4e0"))
    props[6][119] = rgb("566274")
    rect(props, 119, 10, 2, 4, INK)
    rect(props, 116, 14, 8, 1, INK)
    # 8 portátil ejecutivo
    rect(props, 131, 3, 10, 7, INK)
    rect(props, 132, 4, 8, 5, rgb("183c5c"))
    rect(props, 133, 5, 3, 1, rgb("e8b048"))
    rect(props, 130, 10, 12, 3, INK)
    rect(props, 131, 11, 10, 1, rgb("a8a8b4"))
    # 9 climatización
    rect(props, 145, 2, 14, 12, INK)
    rect(props, 146, 3, 12, 10, rgb("c8ccd4"))
    for y in (5, 7, 9):
        rect(props, 147, y, 10, 1, rgb("8c94a0"))
    rect(props, 148, 11, 3, 1, rgb("50e080"))
    rect(props, 154, 11, 2, 1, rgb("e8483c"))
    # 10 cámara de seguridad en poste
    rect(props, 163, 3, 10, 6, INK)
    rect(props, 164, 4, 8, 4, rgb("d8d8e0"))
    rect(props, 170, 5, 2, 2, rgb("183c5c"))
    props[4][165] = rgb("e8483c")
    rect(props, 167, 9, 2, 5, INK)
    rect(props, 164, 14, 8, 1, INK)
    # 11 estación de trabajo: torre grande y monitor ancho
    rect(props, 177, 3, 8, 8, INK)
    rect(props, 178, 4, 6, 6, rgb("6ec8f0"))
    rect(props, 179, 5, 3, 1, rgb("f4f4f8"))
    rect(props, 180, 11, 2, 2, INK)
    rect(props, 186, 2, 6, 13, INK)
    rect(props, 187, 3, 4, 11, rgb("3c4656"))
    props[4][188] = rgb("50e080")
    rect(props, 188, 7, 2, 1, rgb("8c94a0"))
    for index in range(12):
        polish(props, index * 16, 0)
    hero.write_png(ROOT / "assets/sprites/world/office_props.png", props)


def npc_sheet():
    looks = [
        {"T": rgb("b83a4a"), "t": rgb("8e2a3a"), "H": rgb("5a3420"), "j": rgb("7c4a2c")},
        {"T": rgb("3f8a5c"), "t": rgb("2e6a46"), "H": rgb("c89a4c"), "j": rgb("e0b868")},
        {"T": rgb("6a4aa0"), "t": rgb("50367e"), "H": rgb("8c8c98"), "j": rgb("a8a8b4")},
        {"T": rgb("2a8a94"), "t": rgb("1e6a72"), "H": rgb("9a3c28"), "j": rgb("bc5438")},
        {"T": rgb("c47a2c"), "t": rgb("9a5c1e"), "H": rgb("2a2028"), "j": rgb("443844")},
        {"T": rgb("56606e"), "t": rgb("404854"), "H": rgb("6a4a30"), "j": rgb("88643f")},
        {"T": rgb("c84a86"), "t": rgb("9c3468"), "H": rgb("30202c"), "j": rgb("503444")},
        {"T": rgb("7a9a3c"), "t": rgb("5c7a2c"), "H": rgb("d0b070"), "j": rgb("e8cc90")},
        {"T": rgb("20242e"), "t": rgb("14161e"), "H": rgb("b8b8c4"), "j": rgb("d8d8e0")},
        {"T": rgb("2a3a5c"), "t": rgb("1c2840"), "H": rgb("3a3030"), "j": rgb("544848"), "S": rgb("c89070"), "s": rgb("a87050")},
        {"T": rgb("48a0a0"), "t": rgb("347c7c"), "H": rgb("7c5a3c"), "j": rgb("9c7a54")},
        {"T": rgb("d8a020"), "t": rgb("a87c18"), "H": rgb("24242c"), "j": rgb("404050"), "S": rgb("dca680"), "s": rgb("b88860")},
        {"T": rgb("e06c58"), "t": rgb("b45444"), "H": rgb("a85c30"), "j": rgb("c87c48")},
        {"T": rgb("f0f0f4"), "t": rgb("c8c8d4"), "H": rgb("1c1c28"), "j": rgb("383848"), "S": rgb("c89070"), "s": rgb("a87050")},
        {"T": rgb("4c2c5c"), "t": rgb("382044"), "H": rgb("c8c8d0"), "j": rgb("e0e0e8")},
        {"T": rgb("a01c3c"), "t": rgb("7c142c"), "H": rgb("e0b868"), "j": rgb("f0d088")},
    ]
    sheet = canvas(32 * 6, 32 * 4 * len(looks))
    palette = hero.PALETTE
    # Mismo orden que "sprite_frame" en data/npcs.json.
    women = {0, 2, 3, 6, 8, 10, 12, 13, 15}
    for index, look in enumerate(looks):
        swap = {palette[key]: value for key, value in look.items()}
        swap[palette["V"]] = shifted(look["T"], 34)
        swap[palette["L"]] = shifted(look["t"], -10) if index % 3 else rgb("2c2c38")
        swap[palette["l"]] = shifted(swap[palette["L"]], -14)
        for row, direction in enumerate(("down", "right", "up", "left")):
            view = "right" if direction == "left" else direction
            for col, grid in enumerate(hero.movement(view, index in women)):
                if direction == "left":
                    grid = hero.mirrored(grid)
                top = (index * 4 + row) * 32
                for y in range(32):
                    for x in range(32):
                        sheet[top + y][col * 32 + x] = swap.get(grid[y][x], grid[y][x])
    hero.write_png(ROOT / "assets/sprites/npc/npcs.png", sheet)


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


def glow():
    """Luz radial por bandas de píxeles, sin degradado suave."""
    size = 48
    image = canvas(size, size)
    for y in range(size):
        for x in range(size):
            d = ((x - 23.5) ** 2 + (y - 23.5) ** 2) ** 0.5
            level = 255 if d < 7 else 170 if d < 13 else 90 if d < 19 else 40 if d < 23 else 0
            if level and (x + y) % 2 == 0 and d >= 19:
                level //= 2
            if level:
                image[y][x] = (255, 255, 255, level)
    hero.write_png(ROOT / "assets/sprites/world/glow.png", image)
    patch = canvas(24, 40)
    for y in range(40):
        skew = y // 4
        for x in range(2 + skew // 2, 16 + skew // 2):
            if x < 24 and x != 9 + skew // 2:
                patch[y][x] = (255, 244, 200, 70 if y % 2 else 50)
    hero.write_png(ROOT / "assets/sprites/world/window_light.png", patch)


def phone_art():
    frame = canvas(164, 204)
    rect(frame, 2, 0, 160, 204, INK)
    rect(frame, 0, 2, 164, 200, INK)
    rect(frame, 2, 2, 160, 200, rgb("2c3038"))
    rect(frame, 2, 2, 160, 1, rgb("566274"))
    rect(frame, 2, 3, 1, 198, rgb("566274"))
    rect(frame, 6, 12, 152, 178, INK)
    rect(frame, 7, 13, 150, 176, rgb("182036"))
    rect(frame, 7, 13, 150, 1, rgb("2c3c5c"))
    rect(frame, 66, 6, 32, 2, INK)
    rect(frame, 104, 6, 2, 2, rgb("6ec8f0"))
    rect(frame, 72, 193, 20, 6, INK)
    rect(frame, 73, 194, 18, 4, rgb("3c4656"))
    hero.write_png(ROOT / "assets/sprites/ui/phone_frame.png", frame)
    icon = canvas(12, 12)
    rect(icon, 3, 0, 6, 12, INK)
    rect(icon, 4, 1, 4, 8, rgb("6ec8f0"))
    rect(icon, 5, 2, 2, 1, rgb("f4f4f8"))
    rect(icon, 5, 10, 2, 1, rgb("8c94a0"))
    hero.write_png(ROOT / "assets/sprites/ui/phone_icon.png", icon)


def night_room():
    """Apartamento de noche: ventana con ciudad, cama y lámpara, con paneles para el texto."""
    room = canvas(384, 216, rgb("1c1a30"))
    for y in range(0, 150, 16):
        rect(room, 0, y, 384, 1, rgb("24223c"))
    rect(room, 0, 150, 384, 66, rgb("2e2438"))
    for y in range(158, 216, 8):
        rect(room, 0, y, 384, 1, rgb("261e30"))
    rect(room, 262, 10, 104, 74, INK)
    rect(room, 266, 14, 96, 66, rgb("101838"))
    import random as _r
    rng = _r.Random(4)
    for i, h in enumerate((30, 44, 24, 52, 36, 26, 40, 32)):
        rect(room, 266 + i * 12, 80 - h, 11, h, rgb("1c2444"))
        for _ in range(h // 6):
            room[80 - rng.randrange(2, h)][267 + i * 12 + rng.randrange(9)] = rgb("e8c84a")
    rect(room, 313, 14, 2, 66, INK)
    rect(room, 266, 46, 96, 2, INK)
    rect(room, 276, 150, 96, 34, INK)
    rect(room, 278, 152, 92, 12, rgb("e8e4d8"))
    rect(room, 278, 164, 92, 18, rgb("3a5494"))
    rect(room, 278, 164, 92, 2, rgb("566ca8"))
    rect(room, 230, 130, 22, 30, INK)
    rect(room, 232, 132, 18, 26, rgb("6a4a30"))
    rect(room, 236, 112, 10, 18, INK)
    rect(room, 237, 113, 8, 8, rgb("f0d088"))
    # Panel oscuro para la lista
    for y in range(0, 216):
        for x in range(0, 260 if y < 190 else 384):
            r, g, b, a = room[y][x]
            room[y][x] = (r // 2, g // 2, b // 2, a)
    hero.write_png(ROOT / "assets/sprites/ui/night_room.png", room)


def title_screen():
    """Fondo del menú: edificio de LaxCorp al anochecer con ventanas encendidas."""
    image = canvas(384, 216)
    for y in range(216):
        t = y / 215
        top, bottom = (24, 18, 46), (128, 60, 74)
        color = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        for x in range(384):
            dither = (x + y) % 2 == 0 and (y % 9) < 1
            image[y][x] = color + (255,) if not dither else tuple(max(0, c - 8) for c in color) + (255,)
    rng = random.Random(9)
    for _ in range(40):
        image[rng.randrange(0, 90)][rng.randrange(0, 384)] = rgb("f4f4f8")
    for i, (x, w, h) in enumerate(((0, 40, 70), (36, 34, 96), (70, 30, 60), (300, 36, 88), (334, 50, 66))):
        rect(image, x, 216 - h, w, h, rgb("1c1830"))
        for wy in range(216 - h + 6, 212, 8):
            for wx in range(x + 4, x + w - 4, 7):
                if rng.random() < 0.45:
                    rect(image, wx, wy, 3, 4, rgb("e8c84a"))
    rect(image, 200, 40, 90, 176, INK)
    rect(image, 202, 42, 86, 174, rgb("2c3048"))
    rect(image, 202, 42, 86, 3, rgb("3c4466"))
    for wy in range(54, 210, 11):
        for wx in range(208, 282, 12):
            lit = rng.random() < 0.6
            rect(image, wx, wy, 8, 6, rgb("6ec8f0") if lit else rgb("1c2240"))
            if lit:
                rect(image, wx, wy, 8, 1, rgb("c8ecfc"))
    rect(image, 228, 30, 34, 12, INK)
    rect(image, 230, 32, 30, 8, rgb("e8b048"))
    rect(image, 0, 206, 384, 10, rgb("14121e"))
    hero.write_png(ROOT / "assets/sprites/ui/title_bg.png", image)


def stress_fill():
    """Relleno de la barra de estrés, del mismo tamaño que el de reputación."""
    fill = canvas(38, 3, rgb("d84038"))
    rect(fill, 0, 0, 38, 1, rgb("f07860"))
    rect(fill, 0, 2, 38, 1, rgb("a02c30"))
    hero.write_png(ROOT / "assets/sprites/ui/stress_fill.png", fill)


def tool_icons():
    icons = canvas(48, 12)
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
    # 3 tester de red con su cable UTP
    rect(icons, 37, 0, 8, 9, INK)
    rect(icons, 38, 1, 6, 7, rgb("e8b048"))
    rect(icons, 39, 2, 4, 2, rgb("183c2c"))
    rect(icons, 40, 2, 2, 1, rgb("50e080"))
    rect(icons, 39, 5, 1, 1, rgb("e8483c"))
    rect(icons, 42, 5, 1, 1, rgb("50e080"))
    rect(icons, 40, 9, 1, 2, rgb("2c6ad0"))
    rect(icons, 41, 11, 4, 1, rgb("2c6ad0"))
    hero.write_png(ROOT / "assets/sprites/ui/tool_icons.png", icons)


def hud_atlas():
    """Hace opacos los fondos de los paneles para que el texto se lea sobre el mapa."""
    path = ROOT / "assets/sprites/ui/hud_atlas.png"
    data = path.read_bytes()
    pos, idat, width, height, kind = 8, b"", 0, 0, 0
    while pos < len(data):
        size, tag = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + size]
        pos += 12 + size
        if tag == b"IHDR":
            width, height, _, kind = struct.unpack(">IIBB", body[:10])
        elif tag == b"IDAT":
            idat += body
    assert kind == 6
    raw = zlib.decompress(idat)
    stride = width * 4
    rows, prev = [], bytearray(stride)
    for y in range(height):
        line = raw[y * (stride + 1):(y + 1) * (stride + 1)]
        filt, cur = line[0], bytearray(line[1:])
        for i in range(stride):
            left = cur[i - 4] if i >= 4 else 0
            up = prev[i]
            corner = prev[i - 4] if i >= 4 else 0
            if filt == 1:
                cur[i] = (cur[i] + left) & 255
            elif filt == 2:
                cur[i] = (cur[i] + up) & 255
            elif filt == 3:
                cur[i] = (cur[i] + (left + up) // 2) & 255
            elif filt == 4:
                est = left + up - corner
                da, db, dc = abs(est - left), abs(est - up), abs(est - corner)
                cur[i] = (cur[i] + (left if da <= db and da <= dc else up if db <= dc else corner)) & 255
        rows.append(cur)
        prev = cur
    pixels = [[tuple(row[x * 4:x * 4 + 4]) for x in range(width)] for row in rows]
    for y in range(10, 19):
        for x in range(0, 19):
            r, g, b, a = pixels[y][x]
            if 0 < a < 255:
                pixels[y][x] = (r, g, b, 255)
    hero.write_png(path, pixels)


if __name__ == "__main__":
    office_tiles()
    office_props()
    npc_sheet()
    draw_portraits.main()
    warning_icons()
    tool_icons()
    draw_ui_font.main()
    hud_atlas()
    stress_fill()
    glow()
    phone_art()
    night_room()
    title_screen()
    print("arte de oficina generado")
