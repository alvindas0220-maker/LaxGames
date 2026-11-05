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
const FLOORS := {"o": 0, "c": 1, "d": 1, "s": 2, "h": 3, "#": 0, "D": 0, "P": 0, "R": 2}
## Letra del mapa: tile sólido.
const SOLIDS := {"#": 4, "D": 5, "R": 6, "P": 7}
const WALL_CAP := 8
const SPAWN := Vector2i(12, 14)
## id en data/npcs.json y celda: el resto de los datos sale de ese archivo.
const NPCS := [
	["ana", Vector2i(4, 4)],
	["bruno", Vector2i(16, 7)],
	["clara", Vector2i(9, 22)],
	["rrhh", Vector2i(34, 21)],
]
## id, aspecto, celda.
const TERMINALS := [
	["pc_ana", 0, Vector2i(2, 7)],
	["impresora", 1, Vector2i(22, 10)],
	["proyector", 3, Vector2i(10, 18)],
	["servidor", 0, Vector2i(28, 7)],
	["router", 2, Vector2i(38, 10)],
]


func map_rows() -> Array[String]:
	var office := "o".repeat(24)
	var server := "s".repeat(17)
	var hr := "h".repeat(17)
	var desks := "oDDooDDooDDooDDooDDooooo"
	var racks := "sRRsRRsRRsRRsRRss"
	var meeting := "ooooooDDDDDDDDoooooooooP"
	var wall := "#".repeat(44)
	var doors := "###########dd#################dd############"
	var hall := "#" + "c".repeat(42) + "#"
	var room := func(left: String, right: String) -> String: return "#" + left + "#" + right + "#"
	return [
		wall,
		room.call(office, server), room.call(desks, racks), room.call(office, server), room.call(office, server),
		room.call(desks, racks), room.call(office, server), room.call(office, server), room.call(desks, server),
		room.call(office, server), room.call(office, server), room.call(office, server),
		doors, hall, hall, hall, doors,
		room.call(office, hr), room.call(office, hr), room.call(meeting, hr), room.call(meeting, hr),
		room.call(office, hr), room.call(office, hr), room.call(office, hr), room.call(office, hr),
		room.call(office, hr), room.call(office, hr),
		wall,
	]


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
	for i in 9:
		atlas.create_tile(Vector2i(i, 0))
		if SOLIDS.values().has(i) or i == WALL_CAP:
			var data := atlas.get_tile_data(Vector2i(i, 0), 0)
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
	return WALL_CAP if below == "#" else SOLIDS[ch]


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
		assert(rows[y].length() == 44, "fila %d mide %d" % [y, rows[y].length()])
	check_reachable(rows)
	var tileset := build_tileset()

	var root_node := Node2D.new()
	root_node.name = "Office"
	root_node.set_script(load("res://scripts/world/office.gd"))
	var floor_layer := TileMapLayer.new()
	floor_layer.name = "FloorLayer"
	floor_layer.tile_set = tileset
	floor_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var world_layer := TileMapLayer.new()
	world_layer.name = "WorldLayer"
	world_layer.tile_set = tileset
	world_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_owned(root_node, floor_layer, root_node)
	add_owned(root_node, world_layer, root_node)
	for y in rows.size():
		for x in rows[y].length():
			var ch := rows[y][x]
			floor_layer.set_cell(Vector2i(x, y), SOURCE, Vector2i(FLOORS[ch], 0))
			if SOLIDS.has(ch):
				world_layer.set_cell(Vector2i(x, y), SOURCE, Vector2i(solid_tile(rows, x, y), 0))

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
	var player: Node = spawn("res://scenes/player/player.tscn", entities, root_node, SPAWN, "Player")

	var hud: Node = (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	add_owned(root_node, hud, root_node)
	hud.player = player
	hud.world_layer = world_layer
	var over: Node = (load("res://scenes/ui/game_over.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	add_owned(root_node, over, root_node)
	for path: String in ["res://scenes/ui/event_panel.tscn", "res://scenes/ui/day_summary.tscn"]:
		add_owned(root_node, (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE), root_node)

	var packed := PackedScene.new()
	print("pack: ", packed.pack(root_node))
	print("escena: ", ResourceSaver.save(packed, SCENE))
	root_node.free()
	quit(0)
