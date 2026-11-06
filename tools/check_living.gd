extends Node
## Comprueba las paredes de la oficina y el movimiento de los NPC.
##
## Uso:  godot --path . res://tools/check_living.tscn

var fails := 0


func check(label: String, ok: bool, info: Variant = "") -> void:
	if not ok:
		fails += 1
	print("%s %s %s" % ["OK  " if ok else "FAIL", label, info])


func tick(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		await get_tree().process_frame


func _ready() -> void:
	CareerProfile.use_blank_profile()
	WorkdayManager.enabled = false
	EventDirector.enabled = false
	await get_tree().process_frame
	var room: Node = (load("res://scenes/world/office.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(room)
	get_tree().current_scene = room
	await tick(6)

	# Paredes.
	var world: TileMapLayer = room.get_node("WorldLayer")
	check("pared lateral con tapa", world.get_cell_atlas_coords(Vector2i(25, 5)) == Vector2i(8, 0), world.get_cell_atlas_coords(Vector2i(25, 5)))
	check("pared frontal con cara", world.get_cell_atlas_coords(Vector2i(5, 12)) == Vector2i(4, 0), world.get_cell_atlas_coords(Vector2i(5, 12)))
	var data := world.get_cell_tile_data(Vector2i(25, 5))
	check("la tapa colisiona", data != null and data.get_collision_polygons_count(0) == 1)

	# NPC paseando.
	var player: CharacterBody2D = room.get_node("Entities/Player")
	var bruno: Npc = room.get_node("Entities/Npc_bruno")
	var home := bruno.position
	var positions := {}
	var cols := {}
	var rows := {}
	var far := 0.0
	for i in 900:
		await tick(1)
		positions[Vector2i(bruno.position)] = true
		cols[bruno.get_node("Sprite2D").frame % 6] = true
		rows[(bruno.get_node("Sprite2D").frame / 6) % 4] = true
		far = maxf(far, bruno.position.distance_to(home))
	check("se mueve", positions.size() > 10, positions.size())
	check("anima el paso", cols.has(2) and cols.has(3) and cols.has(4) and cols.has(5), cols.keys())
	check("cambia de direccion", rows.size() >= 2, rows.keys())
	check("se queda cerca de su puesto", far < 46.0, far)
	var sheet_look: int = bruno.get_node("Sprite2D").frame / 24
	check("conserva su aspecto", sheet_look == 1, sheet_look)

	# Al hablarle se detiene y mira al jugador.
	bruno.position = home
	player.global_position = bruno.global_position + Vector2(-18, 0)
	await tick(3)
	bruno.interact()
	var stopped_at := bruno.position
	var row: int = (bruno.get_node("Sprite2D").frame / 6) % 4
	check("mira al jugador", row == 3, row)
	await tick(120)
	check("espera mientras hablas", bruno.position == stopped_at, bruno.position)
	var interactor: Interactor = player.get_node("Interactor")
	check("se puede hablar con el", interactor._target != null and interactor._target.prompt == "Hablar", interactor._target)
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path("res://.godot/living_talk.png"))
	TicketManager.reset()

	# Vista de las paredes laterales.
	player.global_position = Vector2(25 * 16 + 40, 6 * 16)
	await tick(60)
	await RenderingServer.frame_post_draw
	img = get_tree().root.get_texture().get_image()
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path("res://.godot/living_walls.png"))

	# Rendimiento con 100 NPC paseando en la misma sala.
	var scene: PackedScene = load("res://scenes/world/npc.tscn")
	var holder: Node = room.get_node("Entities")
	for i in 96:
		var npc: Npc = scene.instantiate()
		npc.npc_id = ["ana", "bruno", "clara", "rrhh"][i % 4]
		npc.position = Vector2(40 + (i % 16) * 22, 180 + int(i / 16.0) * 14) + Vector2(0, 80)
		holder.add_child(npc)
	await tick(30)
	var start := Time.get_ticks_usec()
	await tick(120)
	var ms := (Time.get_ticks_usec() - start) / 120000.0
	check("100 NPC fluidos", ms < 20.0, "%.1f ms por fotograma" % ms)
	print("fallos: ", fails)
	get_tree().quit(1 if fails > 0 else 0)
