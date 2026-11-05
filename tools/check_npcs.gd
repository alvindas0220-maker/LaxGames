extends Node
## Comprueba los datos de NPC, el diálogo dinámico y la carga con 100 personajes.
##
## Uso:  godot --path . res://tools/check_npcs.tscn

var fails := 0


func check(label: String, ok: bool, info: Variant = "") -> void:
	if not ok:
		fails += 1
	print("%s %s %s" % ["OK  " if ok else "FAIL", label, info])


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		await get_tree().process_frame


func _ready() -> void:
	WorkdayManager.enabled = false
	EventDirector.enabled = false
	WorkdayManager.reputation_pace = 1.0
	await get_tree().process_frame
	check("datos cargados", NpcDatabase.ids().size() == 5, NpcDatabase.ids())
	check("rol", NpcDatabase.role_of("clara") == "directiva", NpcDatabase.role_of("clara"))
	check("retrato", NpcDatabase.portrait_of("ana") != null)

	var room: Node = (load("res://scenes/world/office.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(room)
	get_tree().current_scene = room
	await frames(6)
	var hud: Node = room.get_node("HUD")
	var speaker: Label = hud.get_node("%SpeakerLabel")
	var dialog: Label = hud.get_node("%DialogLabel")
	var portrait: TextureRect = hud.get_node("%SpeakerPortrait")
	check("aviso sin retrato", not portrait.visible, dialog.text)

	var clara: Npc = room.get_node("Entities/Npc_clara")
	clara.interact()
	await frames(2)
	check("nombre desde datos", speaker.text == "Clara Méndez - Gerencia", speaker.text)
	check("retrato en pantalla", portrait.visible and portrait.texture == NpcDatabase.portrait_of("clara"))
	check("dialogo inicial y ticket", dialog.text.begins_with("Soy Clara") and dialog.text.contains("proyector"), dialog.text)
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path("res://.godot/npc_dialog.png"))
	clara.interact()
	await frames(2)
	check("sin repetir saludo", dialog.text.begins_with("Sigo esperando"), dialog.text)
	TicketManager.reset()

	var marta: Npc = room.get_node("Entities/Npc_rrhh")
	marta.interact()
	await frames(2)
	check("RR. HH. por datos", speaker.text.begins_with("Marta Vega") and dialog.text.contains("expediente"), dialog.text)
	check("escena unica", marta.scene_file_path == clara.scene_file_path, marta.scene_file_path)

	# Carga de 100 personajes generados solo para esta prueba.
	var entries := []
	for i in 100:
		entries.append({
			"id": "npc_%03d" % i, "name": "Empleado %d" % i, "department": "Pruebas",
			"role": ["soporte", "usuario_comun", "jefe_departamento", "directiva"][i % 4], "portrait": "res://assets/sprites/npc/portraits/ana.png",
			"sprite_frame": i % 4, "dialogue": "Hola, soy el empleado %d." % i,
		})
	var path := "user://npcs_100.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"npcs": entries}))
	file.close()
	var start := Time.get_ticks_usec()
	var count := NpcDatabase.load_from(path)
	var load_ms := (Time.get_ticks_usec() - start) / 1000.0
	check("100 NPC validos", count == 100, "%d en %.1f ms" % [count, load_ms])
	var scene: PackedScene = load("res://scenes/world/npc.tscn")
	var holder := Node2D.new()
	room.add_child(holder)
	for i in 100:
		var npc: Npc = scene.instantiate()
		npc.npc_id = "npc_%03d" % i
		npc.position = Vector2(i % 10, int(i / 10.0)) * 40.0
		holder.add_child(npc)
	await frames(30)
	var last: Npc = holder.get_child(99)
	last.interact()
	await frames(2)
	check("NPC numero 100 habla", speaker.text.begins_with("Empleado 99") and dialog.text.contains("empleado 99"), dialog.text)
	entries = [
		{"id": "bien", "name": "A", "department": "B", "role": "soporte", "portrait": "res://assets/sprites/npc/portraits/ana.png", "sprite_frame": 0, "dialogue": "Hola"},
		{"id": "bien", "name": "Copia", "department": "B", "role": "soporte", "portrait": "res://assets/sprites/npc/portraits/ana.png", "sprite_frame": 0, "dialogue": "Hola"},
		{"id": "rol", "name": "A", "department": "B", "role": "becario", "portrait": "res://assets/sprites/npc/portraits/ana.png", "sprite_frame": 0, "dialogue": "Hola"},
		{"id": "foto", "name": "A", "department": "B", "role": "soporte", "portrait": "res://no/existe.png", "sprite_frame": 0, "dialogue": "Hola"},
		{"id": "campo", "name": "A"},
	]
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"npcs": entries}))
	file.close()
	check("descarta datos erroneos", NpcDatabase.load_from(path) == 2 and NpcDatabase.has_npc("bien") and NpcDatabase.has_npc("foto"), NpcDatabase.ids())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	check("recupera los datos reales", NpcDatabase.load_from(NpcDatabase.DATA_PATH) == 5)
	print("fallos: ", fails)
	get_tree().quit(1 if fails > 0 else 0)
