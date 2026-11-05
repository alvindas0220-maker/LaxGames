extends SceneTree
## Genera la hoja compacta del héroe: 32x32 por fotograma, unos 24 px de alto.
##
## Uso:  godot --headless --path . --script tools/generate_hero_sheet.gd
## La variable de entorno OUT cambia la ruta de salida.
##
## Hoja: 6 columnas x 8 filas.
##   Filas 0-3 (abajo, derecha, arriba, izquierda): idle 1, idle 2, paso A,
##   pies juntos, paso B, pies juntos.
##   Filas 4-7 (mismas direcciones): preparar, golpe, seguir, recuperar.

const F := 32
const COLS := 6
const ROWS := 8
const PAD_X := 6
const HEAD_Y := 7
const TORSO_Y := 17
const LIGHT := Vector2(-0.55, -0.83)
const INK := Color8(20, 14, 30)
const EMPTY := "."

const RAMPS := {
	"hair": ["3a1a22", "642a24", "96472a", "c8743a", "eeb26a"],
	"tunic": ["16235c", "1e3a90", "2c60cc", "4e92ec", "a4d6ff"],
	"cape": ["4a1030", "861a36", "c4303a", "ec6448"],
	"skin": ["96544f", "cf8a66", "f2c196", "ffe0bd"],
	"legs": ["6a5664", "a08a84", "d4c6ac", "f4ead2"],
	"boots": ["2b1a2e", "4b2c38", "734836", "a2714a"],
	"belt": ["3c2230", "6c4230", "9e6e42"],
	"gold": ["7a4a20", "c08a30", "f4ca4e", "fff2a6"],
}
## Por material: [brillo base, fuerza de la luz lateral, degradado vertical].
const LIGHTING := {
	"hair": [0.50, 0.22, 0.18],
	"tunic": [0.50, 0.22, 0.20],
	"cape": [0.50, 0.22, 0.12],
	"skin": [0.70, 0.08, 0.06],
	"legs": [0.62, 0.18, 0.08],
	"boots": [0.50, 0.20, 0.08],
	"belt": [0.55, 0.15, 0.0],
	"gold": [0.62, 0.18, 0.08],
}
## Letra del mapa: [material, ajuste de tono].
const MATERIALS := {
	"H": ["hair", 0], "h": ["hair", -1],
	"T": ["tunic", 0], "t": ["tunic", -1],
	"R": ["cape", 0], "r": ["cape", -1],
	"S": ["skin", 0],
	"L": ["legs", 0], "l": ["legs", -1],
	"O": ["boots", 0], "o": ["boots", -1],
	"B": ["belt", 0],
	"C": ["gold", 0], "y": ["gold", 1],
}
const FLAT := {
	"K": INK, "e": INK, "E": Color8(46, 92, 176), "w": Color8(255, 255, 255),
	"M": Color8(170, 84, 78), "Z": Color8(244, 202, 78),
	"X": Color8(238, 246, 252), "x": Color8(150, 176, 204),
	"A": Color8(250, 254, 255), "a": Color8(150, 214, 255),
}

const HEAD_DOWN := [
	".......K.KK.K.......",
	"......KHKHHKHK......",
	".....KHHHHHHHHK.....",
	"....KHHhHHHHhHHK....",
	"....KHhHHSHHSHhK....",
	"....KHSSSSSSSSHK....",
	"....KHSewSSewSHK....",
	"....KhSeESSeESHK....",
	".....KSSSMMSSSK.....",
	"......KKSSSSKK......",
]
const HEAD_RIGHT := [
	"......KK.KK.........",
	".....KHHKHHK........",
	"....KHHHHHHHHK......",
	"...KHHhHHHHHHHK.....",
	"...KHHHhHHHHSSK.....",
	"....KHHhHHSSSSK.....",
	"....KHHHhSSewSSK....",
	"....KhHHSSSeESSK....",
	".....KHSSSSSMK......",
	"......KKSSSSKK......",
]
const HEAD_UP := [
	".......K.KK.K.......",
	"......KHKHHKHK......",
	".....KHHHHHHHHK.....",
	"....KHHhHHHHhHHK....",
	"....KHhHHHhHHHhK....",
	"....KHHhHHHhHHHK....",
	"....KHHHhHHHHhHK....",
	"....KhHHHHhHHHHK....",
	".....KHHHHHHHHK.....",
	"......KKSSSSKK......",
]
const TORSO_DOWN := [
	"......KCCCCCCK......",
	".....KTTTCCTTTK.....",
	".....KTTTTTTTTK.....",
	".....KTTtTTTTTK.....",
	".....KBBByyBBBK.....",
	".....KTTTTTTTTK.....",
	"......KTtTTtTK......",
]
const TORSO_UP := [
	"......KRRRRRRK......",
	".....KRRRRRRRRK.....",
	".....KRRrRRRRRK.....",
	".....KRRRRrRRRK.....",
	".....KRrRRRRrRK.....",
	".....KRRRRRRRRK.....",
	"......KRRrRRRK......",
]
const TORSO_RIGHT := [
	".......KCCCCK.......",
	"......KTTTTCK.......",
	"......KTTTTTK.......",
	"......KTTtTTK.......",
	"......KBByBBK.......",
	"......KTTTTTK.......",
	"......KTtTTK........",
]

## Mano y punta de la espada por fase; el centro del héroe es x=16.
const SWORD_POSES := {
	"down": [[Vector2i(22, 15), Vector2i(28, 6)], [Vector2i(18, 24), Vector2i(18, 31)], [Vector2i(11, 23), Vector2i(4, 30)], [Vector2i(11, 23), Vector2i(5, 28)]],
	"right": [[Vector2i(12, 15), Vector2i(5, 7)], [Vector2i(21, 20), Vector2i(31, 20)], [Vector2i(20, 22), Vector2i(28, 30)], [Vector2i(19, 23), Vector2i(26, 29)]],
	"up": [[Vector2i(22, 23), Vector2i(28, 30)], [Vector2i(20, 13), Vector2i(20, 2)], [Vector2i(11, 14), Vector2i(4, 6)], [Vector2i(11, 16), Vector2i(5, 10)]],
}
## Centro, radio, grados inicial y final del arco en golpe y seguimiento.
const ARCS := {
	"down": [[Vector2(16, 20), 11.0, 15.0, 170.0], [Vector2(16, 20), 11.0, 120.0, 170.0]],
	"right": [[Vector2(15, 19), 14.0, -120.0, 10.0], [Vector2(15, 19), 14.0, -15.0, 50.0]],
	"up": [[Vector2(16, 17), 14.0, -15.0, -170.0], [Vector2(16, 17), 14.0, -120.0, -170.0]],
}
const LEAN := {"down": Vector2i(0, 1), "right": Vector2i(1, 0), "up": Vector2i(0, -1)}


func blank() -> Array:
	var g := []
	for y in F:
		var row := []
		row.resize(F)
		row.fill(EMPTY)
		g.append(row)
	return g


func paint(g: Array, rows: Array, top: int, shift := Vector2i.ZERO) -> void:
	for y in rows.size():
		var line: String = rows[y]
		assert(line.length() == 20, "fila %d mide %d: %s" % [y, line.length(), line])
		for x in line.length():
			var ch := line[x]
			var px: int = x + PAD_X + shift.x
			var py: int = top + y + shift.y
			if ch != EMPTY and px >= 0 and py >= 0 and px < F and py < F:
				g[py][px] = ch


func sample(points: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in range(points.size() - 1):
		var a: Vector2i = points[i]
		var b: Vector2i = points[i + 1]
		var steps := maxi(maxi(absi(b.x - a.x), absi(b.y - a.y)), 1)
		for s in steps + 1:
			var p := Vector2i(Vector2(a).lerp(Vector2(b), float(s) / steps).round())
			if out.is_empty() or out[-1] != p:
				out.append(p)
	return out


## Trazo con contorno. end_ch colorea los últimos end_len puntos.
func stroke(g: Array, points: Array, width: int, ch: String, end_ch := "", end_len := 0) -> void:
	var line := sample(points)
	var cells := {}
	for i in line.size():
		var mark := end_ch if not end_ch.is_empty() and i >= line.size() - end_len else ch
		for dy in width:
			for dx in width:
				cells[line[i] + Vector2i(dx - width / 2, dy - width / 2)] = mark
	for p: Vector2i in cells:
		for n: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var q: Vector2i = p + n
			if not cells.has(q) and q.x >= 0 and q.y >= 0 and q.x < F and q.y < F:
				g[q.y][q.x] = "K"
	for p: Vector2i in cells:
		if p.x >= 0 and p.y >= 0 and p.x < F and p.y < F:
			g[p.y][p.x] = cells[p]


func leg(g: Array, hip: Vector2i, knee: Vector2i, ankle: Vector2i, toe: Vector2i, far: bool) -> void:
	stroke(g, [hip, knee], 2, "l" if far else "L")
	stroke(g, [knee, ankle], 2, "o" if far else "O")
	stroke(g, [ankle, toe], 2, "o" if far else "O")


func arm(g: Array, shoulder: Vector2i, hand: Vector2i) -> void:
	stroke(g, [shoulder, hand], 2, "T", "S", 2)


## Capa corta que se mece detrás del héroe en la vista lateral.
func cape(g: Array, start: Vector2i, phase: float) -> void:
	var pts: Array = [start]
	for i in range(1, 7):
		var sway := sin(phase + i * 0.9) * minf(i * 0.25, 1.0)
		pts.append(start + Vector2i(Vector2(-i * 0.65 + sway, i * 0.9).round()))
	stroke(g, pts, 3, "R", "r", 3)


func front_figure(view: String, ankles: Array, hands: Array, dy: int, shift := Vector2i.ZERO, sword_arm := false) -> Array:
	var g := blank()
	var up := Vector2i(shift.x, shift.y + dy)
	leg(g, Vector2i(14, 24), Vector2i(14, 26), ankles[0], ankles[0] + Vector2i(-1, 1), false)
	leg(g, Vector2i(18, 24), Vector2i(18, 26), ankles[1], ankles[1] + Vector2i(1, 1), false)
	paint(g, TORSO_DOWN if view == "down" else TORSO_UP, TORSO_Y, up)
	paint(g, HEAD_DOWN if view == "down" else HEAD_UP, HEAD_Y, up)
	var right: Vector2i = hands[1]
	arm(g, Vector2i(11, 19) + up, hands[0] + up)
	arm(g, Vector2i(21, 19) + up, right + (Vector2i.ZERO if sword_arm else up))
	return g


func side_figure(near: Array, far: Array, near_hand: Vector2i, far_hand: Vector2i, dy: int, shift := Vector2i.ZERO, phase := 0.0, sword_arm := false) -> Array:
	var g := blank()
	var up := Vector2i(shift.x, shift.y + dy)
	cape(g, Vector2i(13, 18) + up, phase)
	arm(g, Vector2i(17, 19) + up, far_hand + up)
	leg(g, Vector2i(14, 24), far[0], far[1], far[1] + Vector2i(2, 0), true)
	leg(g, Vector2i(16, 24), near[0], near[1], near[1] + Vector2i(2, 0), false)
	paint(g, TORSO_RIGHT, TORSO_Y, up)
	paint(g, HEAD_RIGHT, HEAD_Y, up)
	arm(g, Vector2i(15, 19) + up, near_hand + (Vector2i.ZERO if sword_arm else up))
	return g


func movement_frames(view: String) -> Array:
	if view == "right":
		var stand_n := [Vector2i(16, 26), Vector2i(17, 28)]
		var stand_f := [Vector2i(15, 26), Vector2i(14, 28)]
		var fwd := [Vector2i(18, 26), Vector2i(20, 28)]
		var back := [Vector2i(14, 26), Vector2i(11, 27)]
		var pass_n := [Vector2i(16, 26), Vector2i(16, 28)]
		var pass_f := [Vector2i(15, 26), Vector2i(15, 27)]
		return [
			side_figure(stand_n, stand_f, Vector2i(16, 24), Vector2i(18, 23), 0, Vector2i.ZERO, 0.0),
			side_figure(stand_n, stand_f, Vector2i(16, 24), Vector2i(18, 23), 1, Vector2i.ZERO, 1.0),
			side_figure(fwd, back, Vector2i(12, 23), Vector2i(19, 23), 0, Vector2i.ZERO, 0.0),
			side_figure(pass_n, pass_f, Vector2i(15, 24), Vector2i(17, 23), -1, Vector2i.ZERO, 1.6),
			side_figure(back, fwd, Vector2i(19, 23), Vector2i(12, 23), 0, Vector2i.ZERO, 3.1),
			side_figure(pass_f, pass_n, Vector2i(15, 24), Vector2i(17, 23), -1, Vector2i.ZERO, 4.7),
		]
	var stance := [Vector2i(13, 28), Vector2i(18, 28)]
	var hands := [Vector2i(10, 24), Vector2i(22, 24)]
	var together := [Vector2i(14, 28), Vector2i(17, 28)]
	return [
		front_figure(view, stance, hands, 0),
		front_figure(view, stance, hands, 1),
		front_figure(view, [Vector2i(14, 28), Vector2i(18, 26)], [Vector2i(11, 23), Vector2i(22, 25)], 0),
		front_figure(view, together, hands, -1),
		front_figure(view, [Vector2i(14, 26), Vector2i(18, 28)], [Vector2i(10, 25), Vector2i(21, 23)], 0),
		front_figure(view, together, hands, -1),
	]


func put(g: Array, p: Vector2i, ch: String, only_empty := false) -> void:
	if p.x < 0 or p.y < 0 or p.x >= F or p.y >= F:
		return
	if only_empty and g[p.y][p.x] != EMPTY:
		return
	g[p.y][p.x] = ch


func draw_arc(g: Array, spec: Array, bright: bool) -> void:
	var center: Vector2 = spec[0]
	var radius: float = spec[1]
	var from: float = spec[2]
	var to: float = spec[3]
	var count := 100
	for i in count + 1:
		var t := float(i) / count
		var ang := deg_to_rad(lerpf(from, to, t))
		var dir := Vector2(cos(ang), sin(ang))
		var width := 2 if t > 0.5 and bright else 1
		for w in width:
			var p := Vector2i((center + dir * (radius - w)).round())
			put(g, p, "A" if w == 0 else "a", true)


func draw_sword(g: Array, hand: Vector2i, tip: Vector2i) -> void:
	var steps := maxi(absi(tip.x - hand.x), absi(tip.y - hand.y))
	var dir := Vector2(tip - hand).normalized()
	var perp := Vector2i(Vector2(-dir.y, dir.x).round())
	var solid: Array[Vector2i] = []
	for i in steps + 1:
		var p := Vector2i(Vector2(hand).lerp(Vector2(tip), float(i) / steps).round())
		var ch := "X" if i % 4 != 3 else "x"
		if i == 0:
			ch = "S"
		elif i == 1:
			ch = "B"
		elif i == 2:
			ch = "Z"
			put(g, p + perp, "Z")
			put(g, p - perp, "Z")
			solid.append(p + perp)
			solid.append(p - perp)
		put(g, p, ch)
		solid.append(p)
	for p in solid:
		for n: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var q: Vector2i = p + n
			if q.x >= 0 and q.y >= 0 and q.x < F and q.y < F and not solid.has(q) and (g[q.y][q.x] == EMPTY or g[q.y][q.x] == "a" or g[q.y][q.x] == "A"):
				g[q.y][q.x] = "K"


func attack_frame(view: String, phase: int) -> Array:
	var lean: Vector2i = LEAN[view]
	var offset: Vector2i = [-lean, lean, lean, Vector2i.ZERO][phase]
	var pose: Array = SWORD_POSES[view][phase]
	var hand: Vector2i = pose[0]
	var g: Array
	if view == "right":
		var fwd := [Vector2i(18, 26), Vector2i(20, 28)]
		var back := [Vector2i(14, 26), Vector2i(11, 28)]
		g = side_figure(fwd, back, hand, Vector2i(13, 23), 0, offset, 2.2 + phase, true)
	else:
		g = front_figure(view, [Vector2i(12, 28), Vector2i(19, 28)], [Vector2i(10, 24), hand], 0, offset, true)
	if phase == 1 or phase == 2:
		draw_arc(g, ARCS[view][phase - 1], phase == 1)
	draw_sword(g, hand, pose[1])
	return g


func mirrored(g: Array) -> Array:
	var out := []
	for row: Array in g:
		var r := row.duplicate()
		r.reverse()
		out.append(r)
	return out


func hex_ramp(name: String) -> Array:
	var out := []
	for h: String in RAMPS[name]:
		out.append(Color.html(h))
	return out


## Distancia al borde de cada material, para simular volumen.
func depth_map(g: Array, name: String) -> Dictionary:
	var depth := {}
	var frontier: Array[Vector2i] = []
	for y in F:
		for x in F:
			var ch: String = g[y][x]
			if MATERIALS.has(ch) and MATERIALS[ch][0] == name:
				depth[Vector2i(x, y)] = 99
	for p: Vector2i in depth:
		for n: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if not depth.has(p + n):
				depth[p] = 1
				frontier.append(p)
				break
	while not frontier.is_empty():
		var next: Array[Vector2i] = []
		for p in frontier:
			for n: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var q: Vector2i = p + n
				if depth.has(q) and depth[q] > depth[p] + 1:
					depth[q] = depth[p] + 1
					next.append(q)
		frontier = next
	return depth


## Devuelve el índice de rampa de cada píxel de un material.
func shade(g: Array, name: String) -> Dictionary:
	var depth := depth_map(g, name)
	var ramp_size: int = RAMPS[name].size()
	var cells: Array = depth.keys()
	var top := F
	var bottom := 0
	for p: Vector2i in cells:
		top = mini(top, p.y)
		bottom = maxi(bottom, p.y)
	var result := {}
	var light: Array = LIGHTING[name]
	for p: Vector2i in cells:
		var h: float = minf(depth[p], 3.0)
		var left: float = minf(depth.get(p + Vector2i.LEFT, 0), 3.0)
		var right: float = minf(depth.get(p + Vector2i.RIGHT, 0), 3.0)
		var up: float = minf(depth.get(p + Vector2i.UP, 0), 3.0)
		var down: float = minf(depth.get(p + Vector2i.DOWN, 0), 3.0)
		var normal := Vector2(left - right, up - down)
		var value: float = light[0] + normal.dot(LIGHT) * light[1] + (h - 1.5) * 0.06
		value -= (float(p.y - top) / maxf(bottom - top, 1.0) - 0.5) * light[2]
		var index := clampi(int(floor(value * ramp_size)), 0, ramp_size - 1)
		var ch: String = g[p.y][p.x]
		result[p] = clampi(index + int(MATERIALS[ch][1]), 0, ramp_size - 1)
	return smooth(result, ramp_size)


## Elimina píxeles aislados de la rampa para que las bandas de luz queden limpias.
func smooth(indices: Dictionary, ramp_size: int) -> Dictionary:
	var out := indices.duplicate()
	for p: Vector2i in indices:
		var counts := {}
		var same := false
		for n: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if indices.has(p + n):
				var v: int = indices[p + n]
				counts[v] = counts.get(v, 0) + 1
				if v == indices[p]:
					same = true
		if not same and not counts.is_empty():
			var best: int = counts.keys()[0]
			for k: int in counts:
				if counts[k] > counts[best]:
					best = k
			out[p] = clampi(best, 0, ramp_size - 1)
	return out


func render(g: Array) -> Image:
	var img := Image.create(F, F, false, Image.FORMAT_RGBA8)
	var tones := {}
	for name: String in RAMPS:
		var indices := shade(g, name)
		var ramp := hex_ramp(name)
		for p: Vector2i in indices:
			tones[p] = ramp[indices[p]]
	for y in F:
		for x in F:
			var ch: String = g[y][x]
			if ch == EMPTY:
				continue
			var p := Vector2i(x, y)
			img.set_pixelv(p, tones[p] if tones.has(p) else FLAT[ch])
	# Contorno selectivo: del lado de la luz toma el tono oscuro del material.
	for y in F:
		for x in F:
			if g[y][x] != "K":
				continue
			var lit: bool = (x > 0 and g[y][x - 1] == EMPTY) or (y > 0 and g[y - 1][x] == EMPTY)
			if not lit:
				continue
			for n: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
				var q := Vector2i(x, y) + n
				if q.x < F and q.y < F and MATERIALS.has(g[q.y][q.x]):
					img.set_pixel(x, y, hex_ramp(MATERIALS[g[q.y][q.x]][0])[0])
					break
	return img


func _initialize() -> void:
	var sheet := Image.create(F * COLS, F * ROWS, false, Image.FORMAT_RGBA8)
	var dirs := ["down", "right", "up", "left"]
	for r in dirs.size():
		var dir: String = dirs[r]
		var view: String = "right" if dir == "left" else dir
		var move := movement_frames(view)
		for c in move.size():
			var g: Array = mirrored(move[c]) if dir == "left" else move[c]
			sheet.blit_rect(render(g), Rect2i(0, 0, F, F), Vector2i(c * F, r * F))
		for phase in 4:
			var g := attack_frame(view, phase)
			if dir == "left":
				g = mirrored(g)
			sheet.blit_rect(render(g), Rect2i(0, 0, F, F), Vector2i(phase * F, (4 + r) * F))
	var out := OS.get_environment("OUT")
	if out.is_empty():
		out = "res://assets/sprites/player/player_sheet.png"
	print("guardado: ", sheet.save_png(out), " tam=", sheet.get_size(), " Hframes=", COLS, " Vframes=", ROWS)
	report(sheet)
	quit(0)


## Comprueba que los pies no se muevan y que la hoja no tenga semitransparencias.
func report(sheet: Image) -> void:
	var partial := 0
	var colors := {}
	for y in sheet.get_height():
		for x in sheet.get_width():
			var p := sheet.get_pixel(x, y)
			if p.a > 0.0 and p.a < 1.0:
				partial += 1
			elif p.a == 1.0:
				colors[p.to_rgba32()] = true
	var drift := 0
	var height := 0
	for r in 4:
		var reference := sheet.get_region(Rect2i(0, r * F, F, F)).get_used_rect()
		height = maxi(height, reference.size.y)
		for c in [0, 1, 3, 5]:
			var used := sheet.get_region(Rect2i(c * F, r * F, F, F)).get_used_rect()
			drift = maxi(drift, absi(used.end.y - reference.end.y))
	print("semitransparentes=", partial, " colores=", colors.size(), " desfase_pies=", drift, " alto_heroe=", height)
