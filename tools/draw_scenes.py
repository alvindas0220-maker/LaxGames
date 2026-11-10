"""Fondos de 384x216 para las escenas de la trama y los epílogos.

Uso: python tools/draw_scenes.py
Salida: assets/sprites/scenes/*.png
"""

import random
from pathlib import Path

import draw_hero_pixels as hero

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/sprites/scenes"
W, H = 384, 216
rgb = hero.rgb
INK = rgb("1a1420")


def canvas(color):
    return [[color] * W for _ in range(H)]


def rect(img, x, y, w, h, color):
    for j in range(max(0, y), min(H, y + h)):
        for i in range(max(0, x), min(W, x + w)):
            img[j][i] = color


def shade(color, amount):
    return tuple(max(0, min(255, c + amount)) for c in color[:3]) + (255,)


def wall_and_floor(img, wall, floor, horizon=132):
    """Pared con zócalo y suelo con juntas, la base de cada sala."""
    rect(img, 0, 0, W, horizon, wall)
    for x in range(0, W, 32):
        rect(img, x, 0, 1, horizon, shade(wall, -10))
    rect(img, 0, horizon - 10, W, 10, shade(wall, -34))
    rect(img, 0, horizon - 10, W, 1, shade(wall, 18))
    rect(img, 0, horizon, W, H - horizon, floor)
    for y in range(horizon + 8, H, 14):
        rect(img, 0, y, W, 1, shade(floor, -14))


def window(img, x, y, w, h, sky_top, sky_bottom, lights=0.0, seed=1):
    rng = random.Random(seed)
    rect(img, x - 3, y - 3, w + 6, h + 6, INK)
    for j in range(h):
        t = j / max(h - 1, 1)
        color = tuple(int(sky_top[i] + (sky_bottom[i] - sky_top[i]) * t) for i in range(3)) + (255,)
        rect(img, x, y + j, w, 1, color)
    if lights:
        for k in range(0, w, 14):
            bh = rng.randrange(h // 4, h // 2)
            rect(img, x + k, y + h - bh, 12, bh, shade(sky_top, -18))
            for wy in range(y + h - bh + 3, y + h - 2, 5):
                for wx in range(x + k + 2, x + k + 10, 4):
                    if rng.random() < lights:
                        rect(img, wx, wy, 2, 2, rgb("e8c84a"))
    rect(img, x + w // 2, y, 2, h, INK)
    rect(img, x, y + h // 2, w, 2, INK)


def desk(img, x, y, w, top, front):
    rect(img, x, y, w, 18, INK)
    rect(img, x + 2, y + 2, w - 4, 6, top)
    rect(img, x + 2, y + 2, w - 4, 1, shade(top, 22))
    rect(img, x + 2, y + 8, w - 4, 8, front)
    rect(img, x + 4, y + 18, 4, 14, INK)
    rect(img, x + w - 8, y + 18, 4, 14, INK)


def monitor(img, x, y, screen=rgb("6ec8f0")):
    rect(img, x, y, 22, 16, INK)
    rect(img, x + 2, y + 2, 18, 11, screen)
    rect(img, x + 3, y + 3, 9, 1, shade(screen, 50))
    rect(img, x + 9, y + 16, 4, 4, INK)


def plant(img, x, y):
    rect(img, x + 2, y + 18, 14, 14, INK)
    rect(img, x + 4, y + 20, 10, 11, rgb("a0583c"))
    for dx, dy, r in ((9, 9, 9), (3, 13, 6), (15, 13, 6)):
        for j in range(-r, r + 1):
            for i in range(-r, r + 1):
                if i * i + j * j <= r * r:
                    img[y + dy + j][x + dx + i] = rgb("2e7a4a") if j > -r // 2 else rgb("4aa468")


def shelf(img, x, y, rows=3):
    rect(img, x, y, 44, rows * 18 + 4, INK)
    rect(img, x + 2, y + 2, 40, rows * 18, rgb("6a4a30"))
    colors = ["b83a4a", "2c6ad0", "e8b048", "3f8a5c", "c8c8d4", "8a5a34"]
    rng = random.Random(x)
    for r in range(rows):
        top = y + 2 + r * 18
        rect(img, x + 2, top + 16, 40, 2, INK)
        bx = x + 4
        while bx < x + 38:
            bw = rng.choice((3, 4, 5))
            rect(img, bx, top + 4, bw, 12, rgb(rng.choice(colors)))
            bx += bw + 1


def lamp_glow(img, cx, cy, radius, tint):
    for j in range(-radius, radius + 1):
        for i in range(-radius, radius + 1):
            d = (i * i + j * j) ** 0.5
            if d < radius and 0 <= cy + j < H and 0 <= cx + i < W and (i + j) % 2 == 0:
                img[cy + j][cx + i] = shade(img[cy + j][cx + i], int(tint * (1 - d / radius)))


def jefatura():
    img = canvas(rgb("3a5a5c"))
    wall_and_floor(img, rgb("c8c0b0"), rgb("3a5a5c"))
    window(img, 220, 22, 120, 76, rgb("6ec8f0"), rgb("c8ecfc"), 0.0)
    shelf(img, 24, 40)
    plant(img, 350, 96)
    desk(img, 120, 120, 150, rgb("5a3424"), rgb("3e2418"))
    monitor(img, 150, 104)
    rect(img, 210, 112, 30, 8, rgb("f4f4f8"))
    rect(img, 214, 114, 22, 1, rgb("8c94a0"))
    rect(img, 248, 108, 8, 12, rgb("f4f4f8"))
    rect(img, 136, 70, 50, 26, INK)
    rect(img, 138, 72, 46, 22, rgb("e8e0c8"))
    rect(img, 142, 76, 30, 2, rgb("2c6ad0"))
    rect(img, 142, 82, 22, 2, rgb("8c94a0"))
    lamp_glow(img, 280, 60, 70, 18)
    return img


def gerencia():
    img = canvas(rgb("b08850"))
    wall_and_floor(img, rgb("4c2c5c"), rgb("b08850"))
    window(img, 30, 16, 324, 92, rgb("1c2444"), rgb("c86048"), 0.5, 3)
    rect(img, 40, 128, 304, 22, INK)
    rect(img, 42, 130, 300, 10, rgb("5a3424"))
    rect(img, 42, 130, 300, 2, rgb("74482f"))
    for x in range(60, 330, 46):
        rect(img, x, 116, 16, 14, INK)
        rect(img, x + 2, 118, 12, 10, rgb("2c2c38"))
        rect(img, x + 4, 132, 10, 4, rgb("f4f4f8"))
    rect(img, 176, 104, 34, 26, INK)
    rect(img, 178, 106, 30, 22, rgb("382044"))
    lamp_glow(img, 192, 60, 90, 14)
    return img


def cafeteria_noche():
    img = canvas(rgb("6a5a40"))
    wall_and_floor(img, rgb("5a5468"), rgb("6a5a40"))
    for y in range(132, H, 14):
        for x in range(0, W, 28):
            if (x // 28 + y // 14) % 2 == 0:
                rect(img, x, y, 28, 14, rgb("5c4c34"))
    rect(img, 20, 96, 160, 30, INK)
    rect(img, 22, 98, 156, 10, rgb("8c94a0"))
    rect(img, 22, 108, 156, 16, rgb("5a3424"))
    rect(img, 60, 74, 24, 24, INK)
    rect(img, 62, 76, 20, 20, rgb("50586a"))
    rect(img, 66, 80, 10, 3, rgb("e8483c"))
    window(img, 236, 24, 120, 70, rgb("101838"), rgb("2c3c6c"), 0.35, 7)
    rect(img, 230, 150, 70, 10, INK)
    rect(img, 232, 152, 66, 4, rgb("e8e0c8"))
    rect(img, 240, 160, 4, 30, INK)
    rect(img, 286, 160, 4, 30, INK)
    rect(img, 258, 140, 8, 10, rgb("f4f4f8"))
    for y in range(H):
        for x in range(W):
            img[y][x] = shade(img[y][x], -40)
    lamp_glow(img, 262, 70, 80, 46)
    return img


def ending_propio():
    img = canvas(rgb("d8cdb0"))
    wall_and_floor(img, rgb("ece6d8"), rgb("b08850"), 140)
    window(img, 24, 14, 336, 96, rgb("f0a060"), rgb("fce8b8"), 0.0)
    for x in (40, 150, 260):
        desk(img, x, 146, 84, rgb("a87a4c"), rgb("7c5636"))
        monitor(img, x + 14, 130)
        monitor(img, x + 48, 130, rgb("50e080"))
    plant(img, 340, 108)
    rect(img, 150, 60, 84, 28, INK)
    rect(img, 152, 62, 80, 24, rgb("2c6ad0"))
    rect(img, 160, 70, 64, 3, rgb("f4f4f8"))
    rect(img, 160, 77, 40, 3, rgb("c8ecfc"))
    lamp_glow(img, 192, 60, 120, 20)
    return img


def ending_oscuro():
    img = canvas(rgb("14121e"))
    wall_and_floor(img, rgb("1c1830"), rgb("201c2c"), 140)
    window(img, 40, 16, 304, 104, rgb("0c0e1c"), rgb("1c2444"), 0.25, 11)
    rng = random.Random(5)
    for _ in range(160):
        x, y = rng.randrange(40, 344), rng.randrange(16, 120)
        rect(img, x, y, 1, 4, rgb("3c4c7c"))
    desk(img, 150, 150, 90, rgb("2c2c38"), rgb("1c1c28"))
    monitor(img, 184, 134, rgb("183c5c"))
    lamp_glow(img, 195, 142, 50, 30)
    return img


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, painter in (("jefatura", jefatura), ("gerencia", gerencia), ("cafeteria_noche", cafeteria_noche),
                          ("ending_propio", ending_propio), ("ending_oscuro", ending_oscuro)):
        hero.write_png(OUT / f"{name}.png", painter())


if __name__ == "__main__":
    main()
