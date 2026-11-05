"""Dibuja la hoja del héroe: traje azul marino, cabello rizado negro y chiva.

Uso:
    python tools/generate_hero_sprite_sheet.py [--preview RUTA.png]

Salida: assets/sprites/player/hero_compact.png
Hoja de 6 columnas x 8 filas, 32x32 por fotograma; el personaje mide 20 px.
  Filas 0-3 (abajo, derecha, arriba, izquierda): idle 1, idle 2, paso A,
  pies juntos, paso B, pies juntos.
  Filas 4-7 (mismas direcciones): preparar, golpe, seguir, recuperar.
"""

import argparse
import math
import struct
import zlib
from pathlib import Path

W = 32
H = 32
COLS = 6
ROWS = 8
PAD_X = 6
HEAD_Y = 10
TORSO_Y = 18
HIP_Y = 25
KNEE_Y = 26
ANKLE_Y = 27
SHOULDER_Y = 20
HAND_Y = 24
LIGHT = (-0.55, -0.83)
EMPTY = "."
OUTPUT = Path(__file__).resolve().parent.parent / "assets/sprites/player/hero_compact.png"
NEIGHBORS = ((-1, 0), (1, 0), (0, -1), (0, 1))


def rgb(value):
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def ramp(*values):
    return [rgb(v) for v in values]


INK = rgb("14101c")
RAMPS = {
    "hair": ramp("08080e", "14141e", "24242f", "3c3c4e", "585870"),
    "suit": ramp("141e44", "1e2e5e", "2c4482", "4266ae", "7ea4e0"),
    "shirt": ramp("9aa4bc", "ccd4e4", "f0f4fa", "ffffff"),
    "skin": ramp("a2604c", "d48f68", "f0bd94", "ffdcb8"),
    "legs": ramp("121c3a", "1c2a54", "2a4076", "3e5c9c"),
    "shoes": ramp("0e0a12", "241a22", "40303a", "74626e"),
    "belt": ramp("361e1a", "683c22", "9c6a34"),
    "gold": ramp("7a4a20", "c08a30", "f8d048", "fff4a8"),
}
# Por material: brillo base, fuerza de la luz lateral, degradado vertical.
LIGHTING = {
    "hair": (0.46, 0.24, 0.16),
    "suit": (0.52, 0.22, 0.18),
    "shirt": (0.66, 0.14, 0.06),
    "skin": (0.70, 0.08, 0.06),
    "legs": (0.52, 0.20, 0.08),
    "shoes": (0.50, 0.22, 0.05),
    "belt": (0.55, 0.15, 0.0),
    "gold": (0.62, 0.18, 0.08),
}
# Letra del mapa: material y ajuste de tono.
MATERIALS = {
    "H": ("hair", 0), "h": ("hair", -1), "j": ("hair", 1),
    "T": ("suit", 0), "t": ("suit", -1),
    "W": ("shirt", 0),
    "S": ("skin", 0), "s": ("skin", -1),
    "L": ("legs", 0), "l": ("legs", -1),
    "O": ("shoes", 0), "o": ("shoes", -1),
    "B": ("belt", 0),
    "C": ("gold", 0),
}
FLAT = {
    "K": INK, "e": rgb("181420"), "w": rgb("ffffff"),
    "M": rgb("b0604e"), "G": rgb("14141e"), "Z": rgb("f8d048"),
    "X": rgb("f0f8ff"), "x": rgb("98b4d0"),
    "A": rgb("fafeff"), "a": rgb("96d6ff"),
}

HEAD_DOWN = [
    ".......K.KK.K.......",
    "......KHjHHjHK......",
    ".....KjHhHjHhjK.....",
    ".....KHjHhjHjHK.....",
    ".....KHSjSSjSHK.....",
    ".....KSeSSSSeSK.....",
    "......KSSMMSSK......",
    ".......KSGGSK.......",
]
HEAD_RIGHT = [
    "......K.KK.K........",
    ".....KHjHHjHK.......",
    "....KjHhHjHhjK......",
    "....KHjHhjHjHK......",
    "....KhHjSSjSSK......",
    ".....KHSSSeSK.......",
    ".....KSSSSMSK.......",
    "......KSSGGK........",
]
HEAD_UP = [
    ".......K.KK.K.......",
    "......KHjHHjHK......",
    ".....KjHhHjHhjK.....",
    ".....KHjHhjHjHK.....",
    ".....KHjhHjHhjK.....",
    ".....KhjHHjhHHK.....",
    "......KHjHHjHK......",
    ".......KSSSSK.......",
]
TORSO_DOWN = [
    ".......KTWWTK.......",
    "......KTTWWTTK......",
    "......KTTWWTTK......",
    "......KTTTCTTK......",
    "......KTtTTtTK......",
    "......KTTTTTTK......",
    "......KKKKKKKK......",
]
TORSO_UP = [
    ".......KTTTTK.......",
    "......KTTTTTTK......",
    "......KTTtTTTK......",
    "......KTTTtTTK......",
    "......KTTTtTTK......",
    "......KTTTtTTK......",
    "......KKKKKKKK......",
]
TORSO_RIGHT = [
    ".......KTWWK........",
    ".......KTTWK........",
    ".......KTTWK........",
    ".......KTTTK........",
    ".......KTtTK........",
    ".......KTTTK........",
    ".......KKKKK........",
]

# Mano y punta de la espada por fase; el centro del personaje es x=16.
SWORD_POSES = {
    "down": [((21, 17), (27, 9)), ((18, 25), (18, 31)), ((12, 24), (5, 30)), ((12, 24), (6, 28))],
    "right": [((12, 16), (6, 9)), ((20, 21), (30, 21)), ((19, 23), (27, 29)), ((18, 24), (25, 28))],
    "up": [((21, 24), (27, 30)), ((19, 15), (19, 3)), ((12, 16), (5, 8)), ((12, 18), (6, 12))],
}
# Centro, radio, grados inicial y final del arco en golpe y seguimiento.
ARCS = {
    "down": [((16, 23), 9.0, 15.0, 170.0), ((16, 23), 9.0, 120.0, 170.0)],
    "right": [((15, 20), 13.0, -120.0, 10.0), ((15, 20), 13.0, -15.0, 50.0)],
    "up": [((16, 18), 13.0, -15.0, -170.0), ((16, 18), 13.0, -120.0, -170.0)],
}
LEAN = {"down": (0, 1), "right": (1, 0), "up": (0, -1)}


def rnd(value):
    return int(math.floor(value + 0.5))


def add(a, b):
    return (a[0] + b[0], a[1] + b[1])


def inside(p):
    return 0 <= p[0] < W and 0 <= p[1] < H


def blank():
    return [[EMPTY] * W for _ in range(H)]


def paint(grid, rows, top, shift=(0, 0)):
    for y, line in enumerate(rows):
        assert len(line) == 20, f"fila {y} mide {len(line)}: {line}"
        for x, ch in enumerate(line):
            p = (x + PAD_X + shift[0], top + y + shift[1])
            if ch != EMPTY and inside(p):
                grid[p[1]][p[0]] = ch


def sample(points):
    out = []
    for a, b in zip(points, points[1:]):
        steps = max(abs(b[0] - a[0]), abs(b[1] - a[1]), 1)
        for s in range(steps + 1):
            t = s / steps
            p = (rnd(a[0] + (b[0] - a[0]) * t), rnd(a[1] + (b[1] - a[1]) * t))
            if not out or out[-1] != p:
                out.append(p)
    return out


def stroke(grid, points, width, ch, end_ch="", end_len=0):
    """Trazo con contorno; end_ch colorea los últimos end_len puntos."""
    line = sample(points)
    cells = {}
    for i, point in enumerate(line):
        mark = end_ch if end_ch and i >= len(line) - end_len else ch
        for dy in range(width):
            for dx in range(width):
                cells[(point[0] + dx - width // 2, point[1] + dy - width // 2)] = mark
    for p in cells:
        for n in NEIGHBORS:
            q = add(p, n)
            if q not in cells and inside(q):
                grid[q[1]][q[0]] = "K"
    for p, mark in cells.items():
        if inside(p):
            grid[p[1]][p[0]] = mark


def leg(grid, hip, knee, ankle, toe, far):
    stroke(grid, [hip, knee, ankle], 2, "l" if far else "L")
    stroke(grid, [ankle, toe], 2, "o" if far else "O")


def arm(grid, shoulder, hand):
    stroke(grid, [shoulder, hand], 2, "T", "S", 1)


def front_figure(view, ankles, hands, dy, shift=(0, 0), sword_arm=False):
    grid = blank()
    up = (shift[0], shift[1] + dy)
    for hip_x, ankle, toe in ((14, ankles[0], (-1, 1)), (17, ankles[1], (1, 1))):
        leg(grid, (hip_x, HIP_Y), (hip_x, min(KNEE_Y, ankle[1])), ankle, add(ankle, toe), False)
    paint(grid, TORSO_DOWN if view == "down" else TORSO_UP, TORSO_Y, up)
    paint(grid, HEAD_DOWN if view == "down" else HEAD_UP, HEAD_Y, up)
    arm(grid, add((12, SHOULDER_Y), up), add(hands[0], up))
    arm(grid, add((19, SHOULDER_Y), up), hands[1] if sword_arm else add(hands[1], up))
    return grid


def side_figure(near, far, near_hand, far_hand, dy, shift=(0, 0), sword_arm=False):
    grid = blank()
    up = (shift[0], shift[1] + dy)
    arm(grid, add((16, SHOULDER_Y), up), add(far_hand, up))
    leg(grid, (14, HIP_Y), far[0], far[1], add(far[1], (2, 1)), True)
    leg(grid, (16, HIP_Y), near[0], near[1], add(near[1], (2, 1)), False)
    paint(grid, TORSO_RIGHT, TORSO_Y, up)
    paint(grid, HEAD_RIGHT, HEAD_Y, up)
    arm(grid, add((15, SHOULDER_Y), up), near_hand if sword_arm else add(near_hand, up))
    return grid


def movement_frames(view):
    if view == "right":
        stand_n, stand_f = ((16, KNEE_Y), (16, ANKLE_Y)), ((14, KNEE_Y), (14, ANKLE_Y))
        fwd, back = ((17, KNEE_Y), (18, ANKLE_Y)), ((13, KNEE_Y), (12, ANKLE_Y - 1))
        pass_n, pass_f = ((15, KNEE_Y), (15, ANKLE_Y)), ((15, KNEE_Y), (15, ANKLE_Y - 1))
        hand = (15, HAND_Y)
        return [
            side_figure(stand_n, stand_f, hand, (17, HAND_Y), 0),
            side_figure(stand_n, stand_f, hand, (17, HAND_Y), 1),
            side_figure(fwd, back, (13, HAND_Y - 1), (18, HAND_Y - 1), 0),
            side_figure(pass_n, pass_f, hand, (16, HAND_Y), -1),
            side_figure(back, fwd, (18, HAND_Y - 1), (13, HAND_Y - 1), 0),
            side_figure(pass_f, pass_n, hand, (16, HAND_Y), -1),
        ]
    stance = ((13, ANKLE_Y), (18, ANKLE_Y))
    hands = ((11, HAND_Y), (20, HAND_Y))
    together = ((14, ANKLE_Y), (17, ANKLE_Y))
    return [
        front_figure(view, stance, hands, 0),
        front_figure(view, stance, hands, 1),
        front_figure(view, ((14, ANKLE_Y), (17, ANKLE_Y - 2)), ((11, HAND_Y - 1), (20, HAND_Y + 1)), 0),
        front_figure(view, together, hands, -1),
        front_figure(view, ((14, ANKLE_Y - 2), (17, ANKLE_Y)), ((11, HAND_Y + 1), (20, HAND_Y - 1)), 0),
        front_figure(view, together, hands, -1),
    ]


def put(grid, p, ch, only_empty=False):
    if inside(p) and not (only_empty and grid[p[1]][p[0]] != EMPTY):
        grid[p[1]][p[0]] = ch


def draw_arc(grid, spec, bright):
    center, radius, start, end = spec
    count = 110
    for i in range(count + 1):
        t = i / count
        angle = math.radians(start + (end - start) * t)
        width = 2 if t > 0.5 and bright else 1
        for w in range(width):
            p = (rnd(center[0] + math.cos(angle) * (radius - w)), rnd(center[1] + math.sin(angle) * (radius - w)))
            put(grid, p, "A" if w == 0 else "a", True)


def draw_sword(grid, hand, tip):
    steps = max(abs(tip[0] - hand[0]), abs(tip[1] - hand[1]))
    length = math.hypot(tip[0] - hand[0], tip[1] - hand[1])
    perp = (rnd(-(tip[1] - hand[1]) / length), rnd((tip[0] - hand[0]) / length))
    solid = []
    for i in range(steps + 1):
        t = i / steps
        p = (rnd(hand[0] + (tip[0] - hand[0]) * t), rnd(hand[1] + (tip[1] - hand[1]) * t))
        ch = "X" if i % 4 != 3 else "x"
        if i == 0:
            ch = "S"
        elif i == 1:
            ch = "B"
        elif i == 2:
            ch = "Z"
            for side in (perp, (-perp[0], -perp[1])):
                guard = add(p, side)
                put(grid, guard, "Z")
                solid.append(guard)
        put(grid, p, ch)
        solid.append(p)
    for p in solid:
        for n in NEIGHBORS:
            q = add(p, n)
            if inside(q) and q not in solid and grid[q[1]][q[0]] in (EMPTY, "a", "A"):
                grid[q[1]][q[0]] = "K"


def attack_frame(view, phase):
    lean = LEAN[view]
    offset = [(-lean[0], -lean[1]), lean, lean, (0, 0)][phase]
    hand, tip = SWORD_POSES[view][phase]
    if view == "right":
        fwd, back = ((17, KNEE_Y), (18, ANKLE_Y)), ((13, KNEE_Y), (12, ANKLE_Y))
        grid = side_figure(fwd, back, hand, (13, HAND_Y - 1), 0, offset, True)
    else:
        grid = front_figure(view, ((13, ANKLE_Y), (18, ANKLE_Y)), ((11, HAND_Y), hand), 0, offset, True)
    if phase in (1, 2):
        draw_arc(grid, ARCS[view][phase - 1], phase == 1)
    draw_sword(grid, hand, tip)
    return grid


def mirrored(grid):
    return [list(reversed(row)) for row in grid]


def depth_map(grid, name):
    """Distancia al borde de cada material, para simular volumen."""
    depth = {
        (x, y): 99
        for y in range(H)
        for x in range(W)
        if grid[y][x] in MATERIALS and MATERIALS[grid[y][x]][0] == name
    }
    frontier = []
    for p in depth:
        if any(add(p, n) not in depth for n in NEIGHBORS):
            depth[p] = 1
            frontier.append(p)
    while frontier:
        following = []
        for p in frontier:
            for n in NEIGHBORS:
                q = add(p, n)
                if q in depth and depth[q] > depth[p] + 1:
                    depth[q] = depth[p] + 1
                    following.append(q)
        frontier = following
    return depth


def smooth(indices):
    """Elimina píxeles aislados para que las bandas de luz queden limpias."""
    out = dict(indices)
    for p, value in indices.items():
        around = [indices[add(p, n)] for n in NEIGHBORS if add(p, n) in indices]
        if around and value not in around:
            out[p] = max(set(around), key=around.count)
    return out


def shade(grid, name):
    """Devuelve el índice de rampa de cada píxel de un material."""
    depth = depth_map(grid, name)
    if not depth:
        return {}
    size = len(RAMPS[name])
    top = min(p[1] for p in depth)
    bottom = max(p[1] for p in depth)
    base, side, vertical = LIGHTING[name]
    result = {}
    for p, d in depth.items():
        level = [min(depth.get(add(p, n), 0), 3) for n in NEIGHBORS]
        normal = (level[0] - level[1], level[2] - level[3])
        value = base + (normal[0] * LIGHT[0] + normal[1] * LIGHT[1]) * side + (min(d, 3) - 1.5) * 0.06
        value -= ((p[1] - top) / max(bottom - top, 1) - 0.5) * vertical
        index = max(0, min(size - 1, int(math.floor(value * size))))
        result[p] = max(0, min(size - 1, index + MATERIALS[grid[p[1]][p[0]]][1]))
    marks = {p: i for p, i in result.items() if MATERIALS[grid[p[1]][p[0]]][1] != 0}
    return {**smooth(result), **marks}


def render(grid):
    tones = {}
    for name in RAMPS:
        for p, index in shade(grid, name).items():
            tones[p] = RAMPS[name][index]
    pixels = [[(0, 0, 0, 0)] * W for _ in range(H)]
    for y in range(H):
        for x in range(W):
            ch = grid[y][x]
            if ch != EMPTY:
                pixels[y][x] = tones.get((x, y), FLAT.get(ch))
    # Contorno selectivo: del lado de la luz toma el tono oscuro del material.
    for y in range(H):
        for x in range(W):
            if grid[y][x] != "K":
                continue
            if not ((x > 0 and grid[y][x - 1] == EMPTY) or (y > 0 and grid[y - 1][x] == EMPTY)):
                continue
            for q in ((x + 1, y), (x, y + 1)):
                if inside(q) and grid[q[1]][q[0]] in MATERIALS:
                    pixels[y][x] = RAMPS[MATERIALS[grid[q[1]][q[0]]][0]][0]
                    break
    return pixels


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
        for col, grid in enumerate(movement_frames(view)):
            blit(render(mirrored(grid) if direction == "left" else grid), col, row)
        for phase in range(4):
            grid = attack_frame(view, phase)
            blit(render(mirrored(grid) if direction == "left" else grid), phase, 4 + row)
    return sheet


def report(sheet):
    colors = {p for row in sheet for p in row if p[3] == 255}
    partial = sum(1 for row in sheet for p in row if 0 < p[3] < 255)
    bottoms = set()
    tops = set()
    for row in range(4):
        rows = [y for y in range(H) if any(p[3] for p in sheet[row * H + y][0:W])]
        bottoms.add(max(rows))
        tops.add(min(rows))
    print(f"guardado: {OUTPUT} ({W * COLS}x{H * ROWS}) Hframes={COLS} Vframes={ROWS}")
    print(f"colores={len(colors)} semitransparentes={partial} suelo={sorted(bottoms)} cabeza={sorted(tops)}")


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
    report(sheet)
    if args.preview:
        write_preview(args.preview, sheet)


if __name__ == "__main__":
    main()
