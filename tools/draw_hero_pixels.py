"""Convierte a PNG las poses del héroe, escritas píxel a píxel en este archivo.

No calcula sombras, luces ni extremidades: cada letra es un color de PALETTE.

Uso:
    python tools/draw_hero_pixels.py [--preview RUTA.png]

Salida: assets/sprites/player/hero_clean.png
Hoja de 6 columnas x 8 filas, 32x32 por fotograma; el personaje mide 20 px.
  Filas 0-3 (abajo, derecha, arriba, izquierda): idle, parpadeo, paso A,
  pies juntos, paso B, pies juntos.
  Filas 4-7 (mismas direcciones): preparar, golpe, seguir, recuperar.
"""

import argparse
import struct
import zlib
from pathlib import Path

W = 32
H = 32
COLS = 6
ROWS = 8
OFFSET_X = 8
OFFSET_Y = 10
OUTPUT = Path(__file__).resolve().parent.parent / "assets/sprites/player/hero_clean.png"


def rgb(value):
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


PALETTE = {
    "K": rgb("1a1420"),  # contorno
    "H": rgb("16161f"),  # cabello
    "j": rgb("34344a"),  # rizo
    "S": rgb("f0c098"),  # piel
    "s": rgb("cc8e6a"),  # piel en sombra
    "e": rgb("16161f"),  # ojo
    "T": rgb("24386e"),  # traje
    "t": rgb("18264e"),  # traje en sombra
    "W": rgb("f4f4f8"),  # camisa
    "L": rgb("1c2c58"),  # pantalón
    "l": rgb("141f40"),  # pantalón de la pierna lejana
    "O": rgb("2e2028"),  # zapato
    "o": rgb("1e151b"),  # zapato de la pierna lejana
    "X": rgb("c8d4e0"),  # punta del destornillador
    "Z": rgb("e0b040"),  # mango del destornillador
}

CROWN = [
    ".....KK.KK.K....",
    "....KjHKjHKjK...",
    "...KHjHHjHHjHK..",
    "...KjHHjHHjHHK..",
    "...KHjHHjHHHjK..",
]
FACE = [
    "...KSHjSSHjSSK..",
    "...KSSSSSSSSSK..",
    "...KSSeSSSeSSK..",
    "....KSSSSSSSK...",
    ".....KKSSSKK....",
]
FACE_BLINK = [
    "...KSHjSSHjSSK..",
    "...KSSSSSSSSSK..",
    "...KSSsSSSsSSK..",
    "....KSSSSSSSK...",
    ".....KKSSSKK....",
]
BACK_HEAD = [
    "...KHjHHjHHjHK..",
    "...KjHHjHHjHHK..",
    "...KHHjHHjHHHK..",
    "....KHHHHHHHK...",
    ".....KKSSSKK....",
]
BODY_FRONT = [
    "....KTTWWWTTK...",
    "...KTTTtWtTTTK..",
    "...KTKTTtTTKTK..",
    "...KTKTTtTTKTK..",
    "...KSKTTtTTKSK..",
    "...KKKTTtTTKKK..",
]
BODY_FRONT_A = [
    "....KTTWWWTTK...",
    "...KTTTtWtTTTK..",
    "...KTKTTtTTKTK..",
    "...KSKTTtTTKTK..",
    "...KKKTTtTTKSK..",
    ".....KTTtTTKKK..",
]
BODY_FRONT_B = [
    "....KTTWWWTTK...",
    "...KTTTtWtTTTK..",
    "...KTKTTtTTKTK..",
    "...KTKTTtTTKSK..",
    "...KSKTTtTTKKK..",
    "...KKKTTtTTK....",
]
BODY_BACK = [
    "....KTTTTTTTK...",
    "...KTTTTTTTTTK..",
    "...KTKTTtTTKTK..",
    "...KTKTTtTTKTK..",
    "...KSKTTtTTKSK..",
    "...KKKTTtTTKKK..",
]
BODY_BACK_A = [
    "....KTTTTTTTK...",
    "...KTTTTTTTTTK..",
    "...KTKTTtTTKTK..",
    "...KSKTTtTTKTK..",
    "...KKKTTtTTKSK..",
    ".....KTTtTTKKK..",
]
BODY_BACK_B = [
    "....KTTTTTTTK...",
    "...KTTTTTTTTTK..",
    "...KTKTTtTTKTK..",
    "...KTKTTtTTKSK..",
    "...KSKTTtTTKKK..",
    "...KKKTTtTTK....",
]
LEGS_STAND = [
    "....KLLKKLLK....",
    "....KLLKKLLK....",
    "....KOOKKOOK....",
    "....KKKKKKKK....",
]
LEGS_A = [
    "....KLLKKLLK....",
    "....KLLKKOOK....",
    "....KOOKKKKK....",
    "....KKKK........",
]
LEGS_B = [
    "....KLLKKLLK....",
    "....KOOKKLLK....",
    "....KKKKKOOK....",
    "........KKKK....",
]
LEGS_TOGETHER = [
    ".....KLLLLK.....",
    ".....KLKKLK.....",
    ".....KOKKOK.....",
    ".....KKKKKK.....",
]

SIDE_HEAD = [
    ".....KK.KK......",
    "....KjHKjHKK....",
    "...KHjHHjHHjK...",
    "...KjHHjHHjHK...",
    "...KHjHHHjHSK...",
    "...KHHjSSHjSK...",
    "...KHHSSSSSSK...",
    "....KHSSSeSSK...",
    ".....KSSSSSSK...",
    "......KSSSK.....",
]
SIDE_HEAD_BLINK = SIDE_HEAD[:7] + ["....KHSSSsSSK...", ] + SIDE_HEAD[8:]
SIDE_BODY = [
    ".....KTTWWK.....",
    ".....KTtTWK.....",
    ".....KTtTWK.....",
    ".....KTtTTK.....",
    ".....KTSTTK.....",
    ".....KTTTTK.....",
]
SIDE_BODY_FORWARD = [
    ".....KTTWWK.....",
    ".....KTTtWK.....",
    ".....KTTtWK.....",
    ".....KTTtTK.....",
    ".....KTTTSK.....",
    ".....KTTTTK.....",
]
SIDE_BODY_BACK = [
    ".....KTTWWK.....",
    ".....KTTTWK.....",
    ".....KTTTWK.....",
    "....KKTTTTK.....",
    "....KSKTTTK.....",
    ".....KTTTTK.....",
]
SIDE_LEGS_STAND = [
    ".....KLLLLK.....",
    ".....KLLLLK.....",
    ".....KOOOOOK....",
    ".....KKKKKKK....",
]
SIDE_LEGS_A = [
    ".....KLLLLK.....",
    "....KllKKLLK....",
    "...KooK..KOOOK..",
    "...KKK...KKKKK..",
]
SIDE_LEGS_B = [
    ".....KLLLLK.....",
    "....KLLKKllK....",
    "...KOOK..KoooK..",
    "...KKK...KKKKK..",
]
SIDE_LEGS_TOGETHER = [
    ".....KLLLLK.....",
    "......KLLK......",
    "......KOOOK.....",
    "......KKKKK.....",
]

# Mano y dirección del destornillador en coordenadas del fotograma, por fase.
SWORD_POSES = {
    "down": [((22, 20), (27, 11)), ((21, 24), (21, 31)), ((10, 24), (4, 30)), ((10, 25), (5, 29))],
    "right": [((11, 18), (5, 11)), ((21, 22), (30, 22)), ((21, 24), (28, 30)), ((19, 25), (25, 29))],
    "up": [((22, 24), (27, 30)), ((21, 19), (21, 7)), ((10, 18), (4, 11)), ((10, 20), (5, 14))],
}


def frame(*parts, lift=0):
    """Une las partes de una pose en una rejilla; lift sube el cuerpo sin mover los pies."""
    rows = [row for part in parts for row in part]
    assert len(rows) == 20, f"pose de {len(rows)} filas"
    grid = [[(0, 0, 0, 0)] * W for _ in range(H)]
    feet = len(rows) - 4
    for y, line in enumerate(rows):
        assert len(line) == 16, f"fila {y} mide {len(line)}: {line}"
        top = y + OFFSET_Y - (lift if y < feet else 0)
        for x, ch in enumerate(line):
            if ch != ".":
                grid[top][x + OFFSET_X] = PALETTE[ch]
    if lift:
        for x, ch in enumerate(rows[feet]):
            if ch != ".":
                grid[feet + OFFSET_Y - lift][x + OFFSET_X] = PALETTE[ch]
    return grid


def put(grid, x, y, color):
    if 0 <= x < W and 0 <= y < H:
        grid[y][x] = color


def screwdriver(grid, hand, tip):
    """Destornillador corto: mango amarillo y punta metálica."""
    steps = max(abs(tip[0] - hand[0]), abs(tip[1] - hand[1]))
    points = [(round(hand[0] + (tip[0] - hand[0]) * i / steps), round(hand[1] + (tip[1] - hand[1]) * i / steps)) for i in range(steps + 1)][:8]
    for x, y in points:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if 0 <= x + dx < W and 0 <= y + dy < H and grid[y + dy][x + dx][3] == 0:
                grid[y + dy][x + dx] = PALETTE["K"]
    for i, (x, y) in enumerate(points):
        put(grid, x, y, PALETTE["S"] if i == 0 else PALETTE["Z"] if i < 4 else PALETTE["X"])


def mirrored(grid):
    return [list(reversed(row)) for row in grid]


def movement(view):
    if view == "right":
        return [
            frame(SIDE_HEAD, SIDE_BODY, SIDE_LEGS_STAND),
            frame(SIDE_HEAD_BLINK, SIDE_BODY, SIDE_LEGS_STAND),
            frame(SIDE_HEAD, SIDE_BODY_BACK, SIDE_LEGS_A),
            frame(SIDE_HEAD, SIDE_BODY, SIDE_LEGS_TOGETHER, lift=1),
            frame(SIDE_HEAD, SIDE_BODY_FORWARD, SIDE_LEGS_B),
            frame(SIDE_HEAD, SIDE_BODY, SIDE_LEGS_TOGETHER, lift=1),
        ]
    if view == "up":
        head = [CROWN, BACK_HEAD]
        return [
            frame(*head, BODY_BACK, LEGS_STAND),
            frame(*head, BODY_BACK, LEGS_STAND),
            frame(*head, BODY_BACK_A, LEGS_A),
            frame(*head, BODY_BACK, LEGS_TOGETHER, lift=1),
            frame(*head, BODY_BACK_B, LEGS_B),
            frame(*head, BODY_BACK, LEGS_TOGETHER, lift=1),
        ]
    return [
        frame(CROWN, FACE, BODY_FRONT, LEGS_STAND),
        frame(CROWN, FACE_BLINK, BODY_FRONT, LEGS_STAND),
        frame(CROWN, FACE, BODY_FRONT_A, LEGS_A),
        frame(CROWN, FACE, BODY_FRONT, LEGS_TOGETHER, lift=1),
        frame(CROWN, FACE, BODY_FRONT_B, LEGS_B),
        frame(CROWN, FACE, BODY_FRONT, LEGS_TOGETHER, lift=1),
    ]


def attack(view, phase):
    base = movement(view)[0]
    grid = [row[:] for row in base]
    hand, tip = SWORD_POSES[view][phase]
    screwdriver(grid, hand, tip)
    return grid


def write_png(path, pixels):
    height = len(pixels)
    width = len(pixels[0])
    raw = bytearray()
    for row in pixels:
        raw.append(0)
        for pixel in row:
            raw.extend(pixel)

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )


def build_sheet():
    sheet = [[(0, 0, 0, 0)] * (W * COLS) for _ in range(H * ROWS)]

    def blit(pixels, col, row):
        for y in range(H):
            sheet[row * H + y][col * W:(col + 1) * W] = pixels[y]

    for row, direction in enumerate(("down", "right", "up", "left")):
        view = "right" if direction == "left" else direction
        for col, grid in enumerate(movement(view)):
            blit(mirrored(grid) if direction == "left" else grid, col, row)
        for phase in range(4):
            grid = attack(view, phase)
            blit(mirrored(grid) if direction == "left" else grid, phase, 4 + row)
    return sheet


def write_preview(path, sheet, scale=4):
    floor = (64, 92, 72, 255)
    rows = []
    for row in sheet:
        wide = []
        for p in row:
            wide.extend([p if p[3] else floor] * scale)
        rows.extend([wide] * scale)
    write_png(path, rows)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preview", type=Path, help="guarda una ampliación sobre el color del suelo")
    args = parser.parse_args()
    sheet = build_sheet()
    write_png(OUTPUT, sheet)
    colors = {p for row in sheet for p in row if p[3] == 255}
    print(f"guardado: {OUTPUT} ({W * COLS}x{H * ROWS}) Hframes={COLS} Vframes={ROWS} colores={len(colors)}")
    if args.preview:
        write_preview(args.preview, sheet)


if __name__ == "__main__":
    main()
