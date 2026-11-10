extends SceneTree
## Construye el TileSet y scenes/world/office.tscn a partir del mapa en texto.
##
## Uso:  godot --headless --path . --script tools/build_office.gd
## Cerrar antes el editor: reescribe la escena.

const TILESET := "res://resources/tilesets/office_tileset.tres"
const SCENE := "res://scenes/world/office.tscn"
const SOURCE := 0
const TILE := 16
## Letra del mapa: tile de suelo.
const FLOORS := {
	"o": 0, "c": 1, "d": 1, "s": 2, "h": 3, "v": 9, "j": 10, "f": 16, "t": 17, "m": 18,
	"#": 0, "W": 0, "V": 0, "G": 0, "K": 0, "D": 0, "T": 0, "P": 0, "F": 0, "I": 0, "Y": 0, "Z": 0, "e": 0,
	"O": 1, "q": 1, "M": 1, "N": 1, "H": 1, "R": 2, "A": 3, "z": 3,
	"L": 9, "U": 9, "B": 9, "x": 9, "J": 10, "Q": 10, "E": 10,
	"u": 16, "k": 16, "n": 16, "b": 16, "a": 16, "g": 16, "w": 17, "i": 17, "r": 18, "X": 18, "l": 18, "y": 18,
}
## Letra del mapa: tile sólido.
const SOLIDS := {
	"#": 4, "W": 13, "V": 32, "G": 33, "K": 34, "D": 5, "J": 5, "R": 42, "P": 7, "Q": 7, "U": 7, "q": 7, "a": 7, "l": 7,
	"T": 45, "L": 45, "F": 12, "A": 12, "B": 12, "I": 20, "Y": 19, "Z": 23, "O": 24, "M": 36, "N": 37, "H": 38,
	"E": 35, "r": 35, "u": 27, "k": 26, "n": 25, "b": 28, "z": 29, "w": 30, "i": 31, "X": 40,
}
## Letra del mapa: detalle sin colisión sobre el suelo.
const DECOR := {"e": 22, "x": 22, "g": 22, "y": 22}
const WALLS := ["#", "W", "V", "G", "K"]
const WALL_CAP := 8
const SHADOW := 14
## Primer fotograma de los tiles animados y fotogramas por segundo.
const ANIMATED := {42: 1.5, 45: 1.1}
const TILE_COUNT := 48
const ATLAS_COLS := 16
const WIDTH := 66
const HEIGHT := 47
## Letreros de cada zona: texto y celda de la pared donde se pintan.
const SIGNS := [
	["HELPDESK", Vector2i(2, 0)],
	["INFRAESTRUCTURA Y REDES", Vector2i(27, 0)],
	["DESARROLLO", Vector2i(45, 0)],
	["SALA DE REUNIONES", Vector2i(2, 16)],
	["RECURSOS HUMANOS", Vector2i(33, 16)],
	["JEFATURA DE IT", Vector2i(45, 16)],
	["ESTACIÓN CENTRAL", Vector2i(31, 27)],
	["CAFETERÍA", Vector2i(2, 34)],
	["BAÑOS", Vector2i(26, 34)],
	["BAÑOS", Vector2i(35, 34)],
	["GERENCIA", Vector2i(45, 34)],
	["SALA DE DESCANSO", Vector2i(30, 41)],
]
const SIGN_INK := Color8(255, 236, 170)
const SPAWN := Vector2i(12, 14)
## id en data/npcs.json y celda: el resto de los datos sale de ese archivo.
const NPCS := [
	["ana", Vector2i(4, 4)],
	["bruno", Vector2i(18, 10)],
	["clara", Vector2i(46, 41)],
	["rrhh", Vector2i(34, 21)],
	["diego", Vector2i(9, 10)],
	["ivan", Vector2i(34, 4)],
	["lucia", Vector2i(48, 4)],
	["tomas", Vector2i(58, 7)],
	["sofia", Vector2i(54, 23)],
	["nadia", Vector2i(33, 29)],
	["carla", Vector2i(7, 36)],
	["hugo", Vector2i(58, 41)],
	["ramon", Vector2i(4, 14)],
	["elena", Vector2i(3, 29)],
	["pablo", Vector2i(27, 14)],
	["ines", Vector2i(60, 29)],
]
## Recorridos en bucle, en celdas.
const ROUTES := {
	"ramon": [Vector2i(4, 14), Vector2i(62, 14)],
	"elena": [Vector2i(3, 29), Vector2i(24, 29), Vector2i(24, 32), Vector2i(3, 32)],
	"pablo": [Vector2i(27, 14), Vector2i(27, 29), Vector2i(45, 29), Vector2i(27, 29)],
	"ines": [Vector2i(60, 29), Vector2i(50, 29), Vector2i(50, 37), Vector2i(50, 29)],
}
## Texto de la acción, texto al usarlo, alivio de estrés, coste de reloj y celda.
const AMENITIES := [
	["Ir al baño", "Te lavas la cara y respiras.", 12.0, 12.0, Vector2i(27, 35)],
	["Ir al baño", "Te lavas la cara y respiras.", 12.0, 12.0, Vector2i(36, 35)],
	["Sentarte un rato", "Cinco minutos de sofá te devuelven la cordura.", 22.0, 24.0, Vector2i(27, 42)],
	["Sentarte un rato", "Cinco minutos de sofá te devuelven la cordura.", 22.0, 24.0, Vector2i(41, 42)],
]
## id, aspecto, celda.
const TERMINALS := [
	["pc_ana", 0, Vector2i(2, 7)],
	["impresora", 1, Vector2i(22, 10)],
	["proyector", 3, Vector2i(10, 18)],
	["servidor", 0, Vector2i(28, 7)],
	["router", 2, Vector2i(38, 10)],
	["switch", 4, Vector2i(34, 10)],
	["pc_helpdesk", 0, Vector2i(14, 10)],
	["pc_dev", 0, Vector2i(47, 8)],
	["build_server", 5, Vector2i(60, 9)],
	["pc_jefatura", 0, Vector2i(59, 24)],
	["pc_gerencia", 0, Vector2i(62, 42)],
	["rack_raid", 6, Vector2i(38, 7)],
	["biometrico", 7, Vector2i(14, 13)],
	["laptop_ejecutiva", 8, Vector2i(55, 37)],
	["hvac", 9, Vector2i(30, 10)],
	["camara", 10, Vector2i(40, 28)],
	["estacion_trabajo", 11, Vector2i(53, 10)],
]
const LUNCH_CELL := Vector2i(11, 39)
const COFFEE_CELL := Vector2i(4, 36)
## Zonas donde se oyen conversaciones de pasillo.
const OVERHEAR := [
	["banos", Vector2i(30, 32)],
	["cafetera", Vector2i(6, 37)],
	["gerencia", Vector2i(51, 32)],
	["infra", Vector2i(31, 14)],
]
## Secretos de la trama: pista, celda y texto al volver a examinarlo.
const CLUE_SPOTS := [
	["factura_nexo", Vector2i(53, 43), "La papelera de Gerencia ya no guarda nada útil."],
	["archivo_rrhh", Vector2i(41, 18), "Solo quedan formularios de vacaciones."],
	["disco_ducto", Vector2i(32, 11), "El ducto de ventilación está vacío."],
	["huella_fantasma", Vector2i(10, 13), "El registro de asistencia parece normal."],
]


func map_rows() -> Array[String]:
	var office := "o".repeat(24)
	var server := "s".repeat(17)
	var dev := "v".repeat(21)
	var boss := "j".repeat(21)
	var cafe := "f".repeat(24)
	var manage := "m".repeat(21)
	var desks := "oTToITTIoTTIoTTIoTTooooo"
	var seats := "oeeooeeooeeooeeooeeooooo"
	var racks := "sRRsRRsRRsRRsRRss"
	var coders := "vLLvvLLvvLLvvLLvvLLvv"
	var coder_seats := "vxxvvxxvvxxvvxxvvxxvv"
	var meeting := "ooooooDDDDDDDDoooooooooP"
	var table := "jjjjjjjJJJJJJJjjjjjjj"
	var tables := "ffbbffbbffbbffbbffbbffff"
	var diners := "ffggffggffggffggffggffff"
	var side := "ccc#hhhhhhhhhhhhh"
	var bath := "tttttttt#tttttttt"
	var lounge := "h".repeat(17)
	var top := "########W###W###W###G##K############G###K########VV##W###W###W#G##"
	var doors_north := "###########dd#################dd######################dd##########"
	var doors_mid := "###########dd#############ddd#dd######################dd##########"
	var doors_south := "###########dd#############ddd#########################dd##########"
	var doors_low := "###########dd################dd#######dd##########dd##############"
	var wall := "#".repeat(WIDTH)
	var hall := "#" + "c".repeat(WIDTH - 2) + "#"
	var hall_decor := "#ccqccccccccccccccOccccqcccccccccccccqcccccccOccccccccccccccqcccc#"
	var station := "#" + "c".repeat(29) + "MNNNNNH" + "c".repeat(28) + "#"
	var room := func(left: String, middle: String, right: String, gap := "#", east := "#") -> String:
		return "#" + left + gap + middle + east + right + "#"
	return [
		top,
		room.call("FF" + "Y".repeat(18) + "oZoP", "F" + "s".repeat(15) + "F", "BB" + "v".repeat(17) + "UU"),
		room.call(desks, racks, coders), room.call(seats, server, coder_seats),
		room.call("ooooo" + "Y".repeat(14) + "ooooo", server, dev),
		room.call(desks, racks, coders), room.call(seats, server, coder_seats),
		room.call("ooooo" + "Y".repeat(7) + "o".repeat(12), server, dev),
		room.call(desks, server, dev), room.call(seats, server, dev),
		room.call(office, server, dev), room.call("P" + "o".repeat(22) + "P", server, "U" + "v".repeat(19) + "U"),
		doors_north, hall_decor, hall, hall, doors_mid,
		room.call(office, "ccc#" + "h".repeat(10) + "AAA", "EE" + "j".repeat(17) + "QQ"), room.call(office, side, boss),
		room.call(meeting, side, boss), room.call(meeting, side, table),
		room.call(office, side, table), room.call(office, side, boss), room.call(office, side, boss), room.call(office, side, boss),
		room.call(office, side, boss), room.call(office, side, "Q" + "j".repeat(19) + "Q"),
		doors_south, hall, hall, station, hall, hall, hall, doors_low,
		room.call("uuukuuuunn" + "f".repeat(13) + "a", "wwwtttii#wwwtttii", "rrrr" + "m".repeat(15) + "rr"),
		room.call(cafe, bath, manage), room.call(tables, bath, manage), room.call(diners, bath, "mmmmmXXXXmmmmXXXXmmmm"),
		room.call(cafe, bath, "mmmmmyyyymmmmyyyymmmm"), room.call(tables, bath, manage), room.call(diners, "#".repeat(17), manage),
		room.call(cafe, "zzzhhhhhhhhhhhzzz", manage), room.call(tables, lounge, manage, "d", "d"), room.call(diners, lounge, manage, "d", "d"),
		room.call("a" + "f".repeat(22) + "a", "A" + "h".repeat(15) + "A", "l" + "m".repeat(19) + "l"),
		wall,
	]


func atlas_cell(index: int) -> Vector2i:
	return Vector2i(index % ATLAS_COLS, index / ATLAS_COLS)


func build_tileset() -> TileSet:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE, TILE)
	tileset.add_physics_layer()
	var atlas := TileSetAtlasSource.new()
	atlas.texture = load("res://assets/sprites/world/office_tiles.png")
	atlas.texture_region_size = Vector2i(TILE, TILE)
	tileset.add_source(atlas, SOURCE)
	var half := TILE / 2.0
	var square := PackedVector2Array([Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)])
	for i in TILE_COUNT:
		if ANIMATED.has(i - 1):
			continue
		atlas.create_tile(atlas_cell(i))
		if ANIMATED.has(i):
			atlas.set_tile_animation_columns(atlas_cell(i), 2)
			atlas.set_tile_animation_frames_count(atlas_cell(i), 2)
			atlas.set_tile_animation_speed(atlas_cell(i), ANIMATED[i])
		if SOLIDS.values().has(i) or i == WALL_CAP:
			var data := atlas.get_tile_data(atlas_cell(i), 0)
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, square)
	print("tileset: ", ResourceSaver.save(tileset, TILESET))
	return load(TILESET)


## Comprueba que se puede llegar andando junto a cada NPC y equipo.
func check_reachable(rows: Array[String]) -> void:
	var blocked := {}
	var extras: Array = []
	for n in NPCS:
		extras.append(n[1])
	for t in TERMINALS:
		extras.append(t[2])
	for cell: Vector2i in extras:
		blocked[cell] = true
	var seen := {SPAWN: true}
	var stack: Array[Vector2i] = [SPAWN]
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		for n: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var q: Vector2i = p + n
			if seen.has(q) or blocked.has(q) or SOLIDS.has(rows[q.y][q.x]):
				continue
			seen[q] = true
			stack.append(q)
	for route: Array in ROUTES.values():
		for cell: Vector2i in route:
			print("OK  " if seen.has(cell) or blocked.has(cell) else "FAIL", " ruta ", cell)
	for cell: Vector2i in extras:
		var ok := false
		for n: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			ok = ok or seen.has(cell + n)
		print("OK  " if ok else "FAIL", " accesible ", cell)


## Una pared solo enseña su cara si debajo hay suelo; si no, se ve la tapa.
func solid_tile(rows: Array[String], x: int, y: int) -> int:
	var ch := rows[y][x]
	if ch != "#":
		return SOLIDS[ch]
	var below := rows[y + 1][x] if y + 1 < rows.size() else "#"
	return WALL_CAP if below in WALLS else SOLIDS[ch]


## Crea una capa de tiles nítida dentro de la oficina.
func tile_layer(root_node: Node, layer_name: String, tileset: TileSet) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = tileset
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_owned(root_node, layer, root_node)
	return layer


func add_signs(root_node: Node) -> void:
	var holder := Node2D.new()
	holder.name = "Signs"
	add_owned(root_node, holder, root_node)
	var font: Font = load("res://assets/fonts/hud_pixel.fnt")
	for entry: Array in SIGNS:
		var label := Label.new()
		label.text = entry[0]
		label.position = Vector2(entry[1] * TILE) + Vector2(0, 2)
		label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", 8)
		label.add_theme_color_override("font_color", SIGN_INK)
		add_owned(holder, label, root_node)


func center(cell: Vector2i) -> Vector2:
	return Vector2(cell * TILE) + Vector2.ONE * TILE / 2.0


func add_owned(parent: Node, node: Node, owner_node: Node) -> void:
	parent.add_child(node)
	node.owner = owner_node


func spawn(path: String, parent: Node, owner_node: Node, cell: Vector2i, node_name: String) -> Node:
	var node: Node2D = (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	node.name = node_name
	node.position = center(cell)
	add_owned(parent, node, owner_node)
	return node


func _initialize() -> void:
	var rows := map_rows()
	for y in rows.size():
		assert(rows[y].length() == WIDTH, "fila %d mide %d" % [y, rows[y].length()])
	assert(rows.size() == HEIGHT, "el mapa mide %d filas" % rows.size())
	check_reachable(rows)
	var tileset := build_tileset()

	var root_node := Node2D.new()
	root_node.name = "Office"
	root_node.set_script(load("res://scripts/world/office.gd"))
	var floor_layer := tile_layer(root_node, "FloorLayer", tileset)
	var decor_layer := tile_layer(root_node, "DecorLayer", tileset)
	var shade_layer := tile_layer(root_node, "ShadeLayer", tileset)
	var world_layer := tile_layer(root_node, "WorldLayer", tileset)
	for y in rows.size():
		for x in rows[y].length():
			var ch := rows[y][x]
			floor_layer.set_cell(Vector2i(x, y), SOURCE, atlas_cell(FLOORS[ch]))
			if DECOR.has(ch):
				decor_layer.set_cell(Vector2i(x, y), SOURCE, atlas_cell(DECOR[ch]))
			if SOLIDS.has(ch):
				world_layer.set_cell(Vector2i(x, y), SOURCE, atlas_cell(solid_tile(rows, x, y)))
			elif y > 0 and rows[y - 1][x] in WALLS:
				shade_layer.set_cell(Vector2i(x, y), SOURCE, atlas_cell(SHADOW))
	add_signs(root_node)

	# Bajo las entidades: la luz cae sobre el mundo y no quema a los personajes.
	add_owned(root_node, (load("res://scenes/world/office_lighting.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE), root_node)
	var entities := Node2D.new()
	entities.name = "Entities"
	entities.y_sort_enabled = true
	add_owned(root_node, entities, root_node)
	for t: Array in TERMINALS:
		var terminal: Node = spawn("res://scenes/world/terminal.tscn", entities, root_node, t[2], "Terminal_" + t[0])
		terminal.target_id = t[0]
		terminal.look = t[1]
	for n: Array in NPCS:
		var npc: Node = spawn("res://scenes/world/npc.tscn", entities, root_node, n[1], "Npc_" + n[0])
		npc.npc_id = n[0]
		if ROUTES.has(n[0]):
			var points := PackedVector2Array()
			for cell: Vector2i in ROUTES[n[0]]:
				points.append(center(cell))
			npc.route = points
	spawn("res://scenes/world/lunch_table.tscn", entities, root_node, LUNCH_CELL, "LunchTable")
	spawn("res://scenes/world/coffee_machine.tscn", entities, root_node, COFFEE_CELL, "CoffeeMachine")
	for z: Array in OVERHEAR:
		var zone: Node = spawn("res://scenes/world/overhear_zone.tscn", entities, root_node, z[1], "Overhear_" + z[0])
		zone.zone = z[0]
	for c: Array in CLUE_SPOTS:
		var clue: Node = spawn("res://scenes/world/clue_spot.tscn", entities, root_node, c[1], "Clue_" + c[0])
		clue.clue_id = c[0]
		clue.empty_text = c[2]
	for a: Array in AMENITIES:
		var amenity: Node = spawn("res://scenes/world/amenity.tscn", entities, root_node, a[4], "Amenity_%d_%d" % [a[4].x, a[4].y])
		amenity.prompt = a[0]
		amenity.rest_text = a[1]
		amenity.relief = a[2]
		amenity.clock_cost = a[3]
		amenity.talk_place = "descanso" if a[0] == "Sentarte un rato" else ""
	var player: Node = spawn("res://scenes/player/player.tscn", entities, root_node, SPAWN, "Player")

	var hud: Node = (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	add_owned(root_node, hud, root_node)
	hud.player = player
	hud.world_layer = world_layer
	var over: Node = (load("res://scenes/ui/game_over.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	add_owned(root_node, over, root_node)
	for path: String in ["res://scenes/ui/repair_bar.tscn", "res://scenes/ui/event_panel.tscn", "res://scenes/ui/day_summary.tscn", "res://scenes/ui/night_menu.tscn", "res://scenes/ui/phone.tscn", "res://scenes/ui/episode_card.tscn", "res://scenes/ui/pause_menu.tscn"]:
		add_owned(root_node, (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE), root_node)

	var packed := PackedScene.new()
	print("pack: ", packed.pack(root_node))
	print("escena: ", ResourceSaver.save(packed, SCENE))
	root_node.free()
	quit(0)
