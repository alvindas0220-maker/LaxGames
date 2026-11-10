extends Node
## Comprueba nombre, averías reales, mapa completo, rutas, descansos y despidos.
##
## Uso:  godot --path . res://tools/check_career.tscn

var fails := 0
var room: Node
var player: CharacterBody2D


func check(label: String, ok: bool, info: Variant = "") -> void:
	if not ok:
		fails += 1
	print("%s %s %s" % ["OK  " if ok else "FAIL", label, info])


func tick(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		await get_tree().process_frame


func press(action: String) -> void:
	for down in [true, false]:
		var e := InputEventAction.new()
		e.action = action
		e.pressed = down
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		await tick(2)


func shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path(path))


func view(cell: Vector2i, path: String) -> void:
	player.global_position = Vector2(cell * 16)
	await tick(30)
	await shot(path)


func open_office() -> void:
	room = (load("res://scenes/world/office.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(room)
	get_tree().current_scene = room
	player = room.get_node("Entities/Player")
	await tick(8)


func _ready() -> void:
	CareerProfile.use_blank_profile()
	WorkdayManager.enabled = false
	EventDirector.enabled = false
	await get_tree().process_frame

	# Pantalla de nombre.
	var entry: Control = (load("res://scenes/ui/name_entry.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(entry)
	get_tree().current_scene = entry
	await tick(4)
	var input: LineEdit = entry.get_node("%NameInput")
	check("foco en el nombre", input.has_focus())
	check("filtra simbolos", CareerProfile.clean_name("CH@E#CO_") == "CHECO", CareerProfile.clean_name("CH@E#CO_"))
	check("acepta acentos", CareerProfile.clean_name("Ñandú 2") == "Ñandú 2")
	check("limita el largo", CareerProfile.clean_name("x".repeat(40)).length() == CareerProfile.MAX_NAME)
	input.text = "CHECO"
	await tick(2)
	await shot("res://.godot/car_name.png")
	entry.confirm("CHECO")
	await tick(10)
	check("sigue a la intro", get_tree().current_scene.name == "IntroCutscene", get_tree().current_scene)
	var intro := get_tree().current_scene
	check("nombre guardado", CareerProfile.player_name == "CHECO")
	check("format", CareerProfile.format("Hola, {player}.") == "Hola, CHECO.")
	var story: Label = intro.get_node("%StoryLabel")
	while not story.text.contains("CHECO"):
		await press("ui_accept")
		await press("ui_accept")
	check("intro con el nombre", story.text.contains("Soy CHECO"), story.text)
	check("hablante con el nombre", intro.get_node("%SpeakerName").text == "CHECO")
	check("nombre vacio", _name_fallback())
	CareerProfile.register_name("CHECO")
	intro.free()

	await open_office()
	var hud: Node = room.get_node("HUD")
	var phone: Phone = room.get_node("Phone")
	phone.open(0)
	check("nombre en el celular", phone.get_node("%IdentityLabel").text.begins_with("CHECO"), phone.get_node("%IdentityLabel").text)
	phone.close()
	var marta: Npc = room.get_node("Entities/Npc_rrhh")
	marta.interact()
	await tick(2)
	var dialog: Label = hud.get_node("%DialogLabel")
	check("expediente con el nombre", dialog.text.contains("CHECO, tu expediente"), dialog.text)

	# Averías reales: herramienta, equipo y procedimiento coherentes.
	var consistent := true
	for ticket: TicketData in TicketManager.catalog:
		var fault: Dictionary = TicketManager.faults.get(ticket.fault, {})
		var ok: bool = not fault.is_empty() and fault["tool"] == ticket.tool and fault["targets"].has(ticket.target_id) and fault["steps"].size() >= ticket.repairs
		for step: Dictionary in ticket.chain:
			var next: Dictionary = TicketManager.faults.get(step["fault"], {})
			ok = ok and not next.is_empty() and next["tool"] == step["tool"] and next["targets"].has(step["target"])
		if not ok:
			print("incoherente: ", ticket.id)
		consistent = consistent and ok
	check("cada ticket con su averia", consistent)
	var build: TicketData = TicketManager.next_for("lucia")
	check("compilacion usa USB en su servidor", build.id == "build_roto" and build.tool == "usb" and build.target_id == "build_server" and build.fault == "dependencias_rotas", build.id)
	TicketManager.accept(build)
	check("procedimiento real", TicketManager.current_step() == "Leer el error de compilación", TicketManager.current_step())
	TicketManager.repair("build_server")
	check("avanza el procedimiento", TicketManager.current_step() == "Reinstalar las dependencias", TicketManager.current_step())
	await tick(2)
	var ticket_label: Label = hud.get_node("%TicketLabel")
	check("averia en HUD", ticket_label.text.contains("Reinstalar las dependencias") and ticket_label.text.contains("USB (3)"), ticket_label.text)
	await press("slot_3")
	await tick(30)
	await shot("res://.godot/car_ticket.png")
	TicketManager.reset()
	await press("slot_1")

	# Mapa completo.
	var world: TileMapLayer = room.get_node("WorldLayer")
	check("mapa ampliado", world.get_used_rect().size == Vector2i(66, 47), world.get_used_rect().size)
	for label: String in ["CAFETERÍA", "BAÑOS", "GERENCIA", "ESTACIÓN CENTRAL", "HELPDESK", "DESARROLLO"]:
		var found := false
		for sign_node: Label in room.get_node("Signs").get_children():
			found = found or sign_node.text == label
		check("zona " + label, found)
	check("mucha gente", get_tree().get_nodes_in_group("npcs").size() == 16, get_tree().get_nodes_in_group("npcs").size())
	var rack_data := world.get_cell_atlas_coords(Vector2i(27, 2))
	check("rack animado", world.tile_set.get_source(0).get_tile_animation_frames_count(rack_data) == 2, rack_data)

	# Patrulla por el pasillo.
	var ramon: Npc = room.get_node("Entities/Npc_ramon")
	var start := ramon.position
	await tick(420)
	check("patrulla", ramon.position.distance_to(start) > 40.0, ramon.position)
	var carla: Npc = room.get_node("Entities/Npc_carla")
	var carla_at := carla.position
	await tick(120)
	check("puesto fijo", carla.position == carla_at)

	# Servicios.
	var coffee := ToolBelt.coffee
	carla.interact()
	await tick(2)
	check("cafe de la cafeteria", ToolBelt.coffee == coffee + 1, ToolBelt.coffee)
	carla.interact()
	await tick(2)
	check("uno al dia", ToolBelt.coffee == coffee + 1 and dialog.text.contains("CHECO"), dialog.text)
	TicketQueue.pending["clara"] = {"ticket": TicketManager.next_for("clara"), "wait": 5.0, "limit": 60.0}
	room.get_node("Entities/Npc_nadia").interact()
	await tick(2)
	check("estacion central informa", dialog.text.contains("Clara") and dialog.text.contains("1 en espera"), dialog.text)
	TicketQueue.pending.clear()

	# Descanso.
	GameState.stress = 50.0
	var sofa: Amenity = room.get_node("Entities/Amenity_27_42")
	player.global_position = sofa.global_position + Vector2(0, 16)
	await tick(6)
	await press("interact")
	check("el sofa relaja", is_equal_approx(GameState.stress, 28.0), GameState.stress)
	await press("interact")
	check("no se abusa", is_equal_approx(GameState.stress, 28.0), dialog.text)

	# Medidor.
	for pair: Array in [[10.0, "Calma"], [45.0, "Tenso"], [75.0, "Alterado"], [95.0, "Crítico"]]:
		GameState.stress = pair[0]
		GameState.add_stress(0.0)
		check("tramo " + pair[1], GameState.stress_level() == pair[1], GameState.stress_level())
	await tick(3)
	phone.refresh()
	check("medidor en el celular", phone.get_node("%ScreenText").text.contains("Estrés 95% Crítico"), phone.get_node("%ScreenText").text)
	phone.close()
	check("pantalla en alerta", hud.get_node("%StressVignette").visible)
	await shot("res://.godot/car_critical.png")

	# Despido con responsabilidad.
	var panel: Control = room.get_node("GameOver/Panel")
	var label: Label = room.get_node("GameOver/Panel/Label")
	GameState.stress = 0.0
	GameState.add_warning("prueba", 3)
	await tick(2)
	check("con responsabilidad", panel.visible and label.text.begins_with("DESPIDO CON RESPONSABILIDAD") and label.text.contains("CHECO") and CareerProfile.severance_level == 1, label.text)
	await shot("res://.godot/car_severance.png")
	await get_tree().create_timer(0.45, true, false, true).timeout
	await press("ui_accept")
	await tick(12)
	room = get_tree().current_scene
	player = room.get_node("Entities/Player")
	check("repite con ventajas", room.name == "Office" and GameState.reputation == 5.0 and ToolBelt.coffee == 4, GameState.reputation)
	CareerProfile.fired_with_severance()
	check("segunda liquidacion baja la cuota", WorkdayManager.quota() == 4, WorkdayManager.quota())
	CareerProfile.fired_with_severance()
	CareerProfile.fired_with_severance()
	check("tope de liquidacion", CareerProfile.severance_level == 3)
	var calm := GameState.stress
	GameState.add_stress(10.0)
	check("estres mas lento", is_equal_approx(GameState.stress - calm, 8.5), GameState.stress)

	# Desliz grave: sin responsabilidad, se pierde todo.
	GameState.stress = 99.0
	GameState.add_stress(5.0)
	await tick(2)
	panel = room.get_node("GameOver/Panel")
	label = room.get_node("GameOver/Panel/Label")
	check("desliz grave", GameState.fired_for_cause and panel.visible and get_tree().paused and label.text.begins_with("DESPIDO SIN RESPONSABILIDAD"), label.text)
	check("insulta a alguien importante", ["Clara", "Sofía", "Hugo", "Inés"].any(func(n: String) -> bool: return GameState.slip_line.contains(n)), GameState.slip_line)
	check("pierde la liquidacion", CareerProfile.severance_level == 0, CareerProfile.severance_level)
	await shot("res://.godot/car_slip.png")
	await get_tree().create_timer(0.45, true, false, true).timeout
	await press("ui_accept")
	await tick(12)
	check("empieza de cero", get_tree().current_scene.name == "MainMenu" and GameState.reputation == 0.0 and ToolBelt.coffee == 3 and not GameState.fired_for_cause, get_tree().current_scene)
	check("conserva el nombre", CareerProfile.player_name == "CHECO")

	# Vistas para revisar el mapa.
	room = (load("res://scenes/world/office.tscn") as PackedScene).instantiate()
	get_tree().current_scene.free()
	get_tree().root.add_child(room)
	get_tree().current_scene = room
	player = room.get_node("Entities/Player")
	await tick(8)
	for cell: Vector2i in [Vector2i(12, 40), Vector2i(33, 37), Vector2i(33, 31), Vector2i(53, 40), Vector2i(12, 6), Vector2i(33, 43)]:
		await view(cell, "res://.godot/car_room_%d_%d.png" % [cell.x, cell.y])
	print("fallos: ", fails)
	get_tree().quit(1 if fails > 0 else 0)


func _name_fallback() -> bool:
	CareerProfile.register_name("   ")
	return CareerProfile.player_name == CareerProfile.DEFAULT_NAME
