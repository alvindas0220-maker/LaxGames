"""Convierte a PNG las poses del héroe, escritas píxel a píxel en este archivo.

No calcula sombras, luces ni extremidades: cada letra es un color de PALETTE.

Uso:
    python tools/draw_hero_pixels.py [--preview RUTA.png]

Salida: assets/sprites/player/hero_clean.png
Hoja de 6 columnas x 8 filas, 32x32 por fotograma; el personaje mide 26 px.
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
POSE_HEIGHT = 26
OFFSET_Y = 4
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
    "V": rgb("3a5494"),  # luz del traje
    "P": rgb("56485a"),  # brillo del zapato
    "n": rgb("e0e0ec"),  # sombra de la camisa
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
    ".....KKKKKK.....",
    "....KHjHHjHK....",
    "....KHHjHHjK....",
    "....KjHHjHHK....",
]
FACE = [
    "....KHSHHSHK....",
    "....KSSSSSSK....",
    "....KSeSSeSK....",
    "....KsSSSSsK....",
    ".....KsSSsK.....",
    "......KSsK......",
]
FACE_BLINK = FACE[:2] + ["....KSsSSsSK...."] + FACE[3:]
BACK_HEAD = [
    "....KHjHHjHK....",
    "....KHHjHHHK....",
    "....KjHHjHHK....",
    "....KHHHHHHK....",
    ".....KHHHHK.....",
    "......KSsK......",
]
SHOULDERS = [
    "....KVTWWTTK....",
    "...KVTTWnTTTK...",
    "...KVKTWnTKTK...",
    "...KVKTTtTKTK...",
    "...KVKTTtTKtK...",
]
BODY_FRONT = SHOULDERS + [
    "...KTKTTtTKtK...",
    "...KSKTTtTKSK...",
    "...KKKLLLLKKK...",
]
BODY_FRONT_A = SHOULDERS + [
    "...KSKTTtTKtK...",
    "...KKKTTtTKSK...",
    ".....KLLLLKKK...",
]
BODY_FRONT_B = SHOULDERS + [
    "...KTKTTtTKSK...",
    "...KSKTTtTKKK...",
    "...KKKLLLLK.....",
]
BACK_TOP = [
    "....KVTTTTTK....",
    "...KVTTTTTTTK...",
    "...KVKTTtTKTK...",
]
BODY_BACK = BACK_TOP + BODY_FRONT[3:]
BODY_BACK_A = BACK_TOP + BODY_FRONT_A[3:]
BODY_BACK_B = BACK_TOP + BODY_FRONT_B[3:]
LEGS_STAND = [
    ".....KLLLLK.....",
    "....KLlKKLlK....",
    "....KLlKKLlK....",
    "....KLlKKLlK....",
    "....KLlKKLlK....",
    "....KLlKKLlK....",
    "....KPOKKPOK....",
    "....KKKKKKKK....",
]
LEGS_A = [
    ".....KLLLLK.....",
    "....KLlKKLlK....",
    "....KLlKKLlK....",
    "....KLlKKLlK....",
    "....KLlKKPOK....",
    "....KLlKKKKK....",
    "....KPOK........",
    "....KKKK........",
]
LEGS_B = [
    ".....KLLLLK.....",
    "....KLlKKLlK....",
    "....KLlKKLlK....",
    "....KLlKKLlK....",
    "....KPOKKLlK....",
    "....KKKKKLlK....",
    "........KPOK....",
    "........KKKK....",
]
LEGS_TOGETHER = [
    ".....KLLLLK.....",
    ".....KLllLK.....",
    ".....KLKKLK.....",
    ".....KLKKLK.....",
    ".....KLKKLK.....",
    ".....KLKKLK.....",
    ".....KOKKOK.....",
    ".....KKKKKK.....",
]

SIDE_HEAD = [
    ".....KKKKK......",
    "....KHjHHjK.....",
    "....KHHjHHHK....",
    "....KjHHjHHK....",
    "....KHHjHSSK....",
    "....KHHSSSSK....",
    "....KHSSSeSK....",
    ".....KSSSSSK....",
    "......KsSSK.....",
    "......KSsK......",
]
SIDE_HEAD_BLINK = SIDE_HEAD[:6] + ["....KHSSSsSK...."] + SIDE_HEAD[7:]
SIDE_TOP = [
    ".....KVTWWK.....",
    ".....KVTTWK.....",
    ".....KVtTTK.....",
    ".....KVtTTK.....",
    ".....KVtTTK.....",
]
SIDE_BODY = SIDE_TOP + [
    ".....KTtTTK.....",
    ".....KTSTTK.....",
    ".....KLLLLK.....",
]
SIDE_BODY_FORWARD = SIDE_TOP + [
    ".....KTTtTK.....",
    ".....KTTTSK.....",
    ".....KLLLLK.....",
]
SIDE_BODY_BACK = SIDE_TOP + [
    "....KKTTTTK.....",
    "....KSKTTTK.....",
    ".....KLLLLK.....",
]
SIDE_LEGS_STAND = [
    ".....KLLLlK.....",
    ".....KLLLlK.....",
    ".....KLLLlK.....",
    ".....KLLLlK.....",
    ".....KLLLlK.....",
    ".....KLLLlK.....",
    ".....KOOOPPK....",
    ".....KKKKKKK....",
]
SIDE_LEGS_A = [
    ".....KLLLLK.....",
    "....KlLKKLLK....",
    "....KllKKLLK....",
    "...KllK..KLLK...",
    "...KllK..KLLK...",
    "...KllK..KLLLK..",
    "..KooK...KOPPK..",
    "..KKKK...KKKKK..",
]
SIDE_LEGS_B = [
    ".....KLLLLK.....",
    "....KLLKKlLK....",
    "....KLLKKllK....",
    "...KLLK..KllK...",
    "...KLLK..KllK...",
    "...KLLK..KlllK..",
    "..KOPK...KoooK..",
    "..KKKK...KKKKK..",
]
SIDE_LEGS_TOGETHER = [
    ".....KLLLlK.....",
    ".....KLLLlK.....",
    ".....KLLLlK.....",
    "......KLLK......",
    "......KLLK......",
    "......KLLK......",
    "......KOPPK.....",
    "......KKKKK.....",
]

CROWN_F = [
    ".....KKKKKK.....",
    "....KHHHHHHK....",
    "...KHjjHHHHHK...",
    "...KHjHHHHHHK...",
]
FACE_F = [
    "...KHHSHHSHHK...",
    "...KHSSSSSSHK...",
    "...KHSeSSeSHK...",
    "...KHsSSSSsHK...",
    "...KHHsSSsHHK...",
    "...KHHKSsKHHK...",
]
FACE_F_BLINK = FACE_F[:2] + ["...KHSsSSsSHK..."] + FACE_F[3:]
BACK_HEAD_F = [
    "...KHjHHHHjHK...",
    "...KHHHHHHHHK...",
    "...KHjHHHHjHK...",
    "...KHHHHHHHHK...",
    "...KHHHHHHHHK...",
    "...KHjHHHHjHK...",
]
SHOULDERS_F = [
    "...KHKVWWTKHK...",
    "...KVTTWnTTTK...",
    "...KVKTWnTKTK...",
    "...KVKTTtTKTK...",
    "...KVKTTtTKtK...",
]
BODY_FRONT_F = SHOULDERS_F + [
    "...KTKTTtTKtK...",
    "...KSKTTtTKSK...",
    "...KKKTTTTKKK...",
]
BODY_FRONT_F_A = SHOULDERS_F + [
    "...KSKTTtTKtK...",
    "...KKKTTtTKSK...",
    ".....KTTTTKKK...",
]
BODY_FRONT_F_B = SHOULDERS_F + [
    "...KTKTTtTKSK...",
    "...KSKTTtTKKK...",
    "...KKKTTTTK.....",
]
BACK_TOP_F = [
    "...KHHHHHHHHK...",
    "...KVHHHHHHTK...",
    "...KVKHHHHKTK...",
]
BODY_BACK_F = BACK_TOP_F + BODY_FRONT_F[3:]
BODY_BACK_F_A = BACK_TOP_F + BODY_FRONT_F_A[3:]
BODY_BACK_F_B = BACK_TOP_F + BODY_FRONT_F_B[3:]
SKIRT_F = [
    "....KTTTttTK....",
    "....KTTTttTK....",
    "....KTTttTTK....",
]
LEGS_STAND_F = SKIRT_F + [
    ".....KSKKsK.....",
    ".....KSKKsK.....",
    ".....KSKKsK.....",
    ".....KPKKPK.....",
    ".....KKKKKK.....",
]
LEGS_A_F = SKIRT_F + [
    "....KSsKKsSK....",
    "....KSsKKPOK....",
    "....KSsKKKKK....",
    "....KPOK........",
    "....KKKK........",
]
LEGS_B_F = SKIRT_F + [
    "....KsSKKSsK....",
    "....KPOKKSsK....",
    "....KKKKKSsK....",
    "........KPOK....",
    "........KKKK....",
]
LEGS_TOGETHER_F = [
    ".....KTTttK.....",
    ".....KTTttK.....",
    ".....KTTttK.....",
    ".....KSKKsK.....",
    ".....KSKKsK.....",
    ".....KSKKsK.....",
    ".....KPKKPK.....",
    ".....KKKKKK.....",
]
SIDE_HEAD_F = [
    ".....KKKKK......",
    "....KHHHHHK.....",
    "...KHjjHHHHK....",
    "...KHjHHHHHK....",
    "...KHHHHHSSK....",
    "...KHHHHSSSK....",
    "...KHHHSSeSK....",
    "...KHHHSSSSK....",
    "...KHHHKsSK.....",
    "...KHHHKSsK.....",
]
SIDE_HEAD_F_BLINK = SIDE_HEAD_F[:6] + ["...KHHHSSsSK...."] + SIDE_HEAD_F[7:]
SIDE_TOP_F = [
    "...KHHKVWWK.....",
    "...KHHKTTWK.....",
] + SIDE_TOP[2:]
SIDE_BODY_F = SIDE_TOP_F + SIDE_BODY[5:7] + [".....KTTTTK....."]
SIDE_BODY_F_FORWARD = SIDE_TOP_F + SIDE_BODY_FORWARD[5:7] + [".....KTTTTK....."]
SIDE_BODY_F_BACK = SIDE_TOP_F + SIDE_BODY_BACK[5:7] + [".....KTTTTK....."]
SIDE_SKIRT_F = [
    ".....KTTTtK.....",
    ".....KTTTtK.....",
    ".....KTTTtK.....",
]
SIDE_LEGS_STAND_F = SIDE_SKIRT_F + [
    "......KSsK......",
    "......KSsK......",
    "......KSsK......",
    "......KPOOK.....",
    "......KKKKK.....",
]
SIDE_LEGS_A_F = SIDE_SKIRT_F + [
    "....KssKKSsK....",
    "...KssK..KSsK...",
    "...KssK..KSSsK..",
    "..KooK...KPOOK..",
    "..KKKK...KKKKK..",
]
SIDE_LEGS_B_F = SIDE_SKIRT_F + [
    "....KSsKKssK....",
    "...KSsK..KssK...",
    "...KSsK..KsssK..",
    "..KPOK...KoooK..",
    "..KKKK...KKKKK..",
]
SIDE_LEGS_TOGETHER_F = SIDE_LEGS_STAND_F

# Mano y dirección del destornillador en coordenadas del fotograma, por fase.
SWORD_POSES = {
    "down": [((22, 20), (27, 11)), ((21, 24), (21, 31)), ((10, 24), (4, 30)), ((10, 25), (5, 29))],
    "right": [((11, 18), (5, 11)), ((21, 22), (30, 22)), ((21, 24), (28, 30)), ((19, 25), (25, 29))],
    "up": [((22, 24), (27, 30)), ((21, 19), (21, 7)), ((10, 18), (4, 11)), ((10, 20), (5, 14))],
}


def frame(*parts, lift=0):
    """Une las partes de una pose en una rejilla; lift sube el cuerpo sin mover los pies."""
    rows = [row for part in parts for row in part]
    assert len(rows) == POSE_HEIGHT, f"pose de {len(rows)} filas"
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


def movement(view, female=False):
    if female:
        return movement_female(view)
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


def movement_female(view):
    if view == "right":
        return [
            frame(SIDE_HEAD_F, SIDE_BODY_F, SIDE_LEGS_STAND_F),
            frame(SIDE_HEAD_F_BLINK, SIDE_BODY_F, SIDE_LEGS_STAND_F),
            frame(SIDE_HEAD_F, SIDE_BODY_F_BACK, SIDE_LEGS_A_F),
            frame(SIDE_HEAD_F, SIDE_BODY_F, SIDE_LEGS_TOGETHER_F, lift=1),
            frame(SIDE_HEAD_F, SIDE_BODY_F_FORWARD, SIDE_LEGS_B_F),
            frame(SIDE_HEAD_F, SIDE_BODY_F, SIDE_LEGS_TOGETHER_F, lift=1),
        ]
    if view == "up":
        head = [CROWN_F, BACK_HEAD_F]
        return [
            frame(*head, BODY_BACK_F, LEGS_STAND_F),
            frame(*head, BODY_BACK_F, LEGS_STAND_F),
            frame(*head, BODY_BACK_F_A, LEGS_A_F),
            frame(*head, BODY_BACK_F, LEGS_TOGETHER_F, lift=1),
            frame(*head, BODY_BACK_F_B, LEGS_B_F),
            frame(*head, BODY_BACK_F, LEGS_TOGETHER_F, lift=1),
        ]
    return [
        frame(CROWN_F, FACE_F, BODY_FRONT_F, LEGS_STAND_F),
        frame(CROWN_F, FACE_F_BLINK, BODY_FRONT_F, LEGS_STAND_F),
        frame(CROWN_F, FACE_F, BODY_FRONT_F_A, LEGS_A_F),
        frame(CROWN_F, FACE_F, BODY_FRONT_F, LEGS_TOGETHER_F, lift=1),
        frame(CROWN_F, FACE_F, BODY_FRONT_F_B, LEGS_B_F),
        frame(CROWN_F, FACE_F, BODY_FRONT_F, LEGS_TOGETHER_F, lift=1),
    ]


def attack(view, phase, female=False):
    base = movement(view, female)[0]
    grid = [row[:] for row in base]
    hand, tip = SWORD_POSES[view][phase]
    screwdriver(grid, hand, tip)
    return grid


# La protagonista lleva el mismo traje; solo cambia su pelo.
FEMALE_COLORS = {PALETTE["H"]: rgb("3a2430"), PALETTE["j"]: rgb("643e50")}
OUTPUT_FEMALE = OUTPUT.with_name("hero_female.png")


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


def recolor(grid, swap):
    return [[swap.get(p, p) for p in row] for row in grid]


def build_sheet(female=False):
    sheet = [[(0, 0, 0, 0)] * (W * COLS) for _ in range(H * ROWS)]
    swap = FEMALE_COLORS if female else {}

    def blit(pixels, col, row):
        for y in range(H):
            sheet[row * H + y][col * W:(col + 1) * W] = pixels[y]

    for row, direction in enumerate(("down", "right", "up", "left")):
        view = "right" if direction == "left" else direction
        for col, grid in enumerate(movement(view, female)):
            grid = recolor(grid, swap)
            blit(mirrored(grid) if direction == "left" else grid, col, row)
        for phase in range(4):
            grid = recolor(attack(view, phase, female), swap)
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
    write_png(OUTPUT_FEMALE, build_sheet(True))
    colors = {p for row in sheet for p in row if p[3] == 255}
    print(f"guardado: {OUTPUT} ({W * COLS}x{H * ROWS}) Hframes={COLS} Vframes={ROWS} colores={len(colors)}")
    if args.preview:
        write_preview(args.preview, sheet)


if __name__ == "__main__":
    main()
