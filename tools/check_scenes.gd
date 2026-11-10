extends Node
## Comprueba escenas de decisión, epílogos, rutina de los NPC y reacciones a la trama.
##
## Uso:  godot --path . res://tools/check_scenes.tscn

var fails := 0
var room: Node


func check(label: String, ok: bool, info: Variant = "") -> void:
	if not ok:
		fails += 1
	print("%s %s %s" % ["OK  " if ok else "FAIL", label, info])


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func press(action: String) -> void:
	for down in [true, false]:
		var e := InputEventAction.new()
		e.action = action
		e.pressed = down
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		await frames(2)


func wait_guard() -> void:
	await get_tree().create_timer(0.45, true, false, true).timeout


func shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path(path))


func load_office() -> void:
	if room != null:
		room.queue_free()
		await frames(2)
	room = (load("res://scenes/world/office.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(room)
	get_tree().current_scene = room
	await frames(6)
	room.get_node("EpisodeCard/Panel").hide()
	get_tree().paused = false


func _ready() -> void:
	CareerProfile.use_blank_profile()
	StoryDirector.enabled = true
	EventDirector.enabled = false
	await get_tree().process_frame
	await load_office()

	# Escena antes de la decisión.
	var stage: StoryScene = room.get_node("StoryScene")
	var panel: Control = room.get_node("EventPanel/Panel")
	GameState.reputation = 80.0
	for id: String in ["factura_nexo", "pagos_ana", "licencias_ivan", "cunado_bruno", "archivo_rrhh"]:
		StoryDirector.discover(id)
	await frames(4)
	check("la escena va primero", stage.is_playing() and not panel.visible and get_tree().paused)
	check("habla Sofia", stage.get_node("%SceneSpeaker").text.begins_with("Sofía"), stage.get_node("%SceneSpeaker").text)
	await get_tree().create_timer(1.2).timeout
	await shot("res://.godot/scene_act1.png")
	var lines: int = stage._lines.size()
	for i in lines * 2:
		await wait_guard()
		await press("ui_accept")
		if not stage.is_playing():
			break
	await frames(3)
	check("despues de la escena, la decision", not stage.is_playing() and panel.visible, panel.visible)
	room.get_node("EventPanel")._select(0)
	await wait_guard()
	await press("ui_accept")
	await frames(3)
	check("decision tomada", StoryDirector.act == 2 and StoryDirector.flags.has("confia_sofia"))

	# Reacciones: Hugo cae, el letrero cambia y nadie pide tickets por él.
	StoryDirector.set_flag("ruta_honesta")
	await load_office()
	check("Hugo ya no esta", room.get_node_or_null("Entities/Npc_hugo") == null or room.get_node("Entities/Npc_hugo").is_queued_for_deletion())
	check("no pide tickets", not TicketQueue.add("hugo") and not TicketQueue.add_ticket("junta_consejo"))
	var signs := room.get_node("Signs").get_children().map(func(label: Label) -> String: return label.text)
	check("letrero intervenido", "GERENCIA (INTERVENIDA)" in signs, signs)
	check("letrero de Sofia", "JEFATURA DE IT - S. REYES" in signs)

	# Gestos al acercarse.
	Friends.change("ana", 60)
	var ana: Npc = room.get_node("Entities/Npc_ana")
	var player: Node2D = room.get_node("Entities/Player")
	player.global_position = ana.global_position + Vector2(120, 0)
	await frames(4)
	player.global_position = ana.global_position + Vector2(20, 0)
	await frames(4)
	check("gesto de amistad", ana._emote_left > 0.0 and ana.emote() == 1)
	await shot("res://.godot/scene_emote.png")
	Factions.change({"desarrollo": -40})
	check("gesto de enfado", room.get_node("Entities/Npc_lucia").emote() == -1)

	# Rutina: a comer a la cafetería y de vuelta al puesto.
	TicketQueue.reset()
	TicketQueue._timer = 999.0
	var bruno: Npc = room.get_node("Entities/Npc_bruno")
	var desk := bruno.global_position
	var life: OfficeLife = room.get_node("OfficeLife")
	check("asientos de la cafeteria", life._seats.size() >= 8, life._seats.size())
	WorkdayManager.clock = 150.0
	for i in 60:
		await get_tree().physics_frame
	check("salen a almorzar", not bruno._trip.is_empty() or bruno.global_position.distance_to(desk) > 32.0)
	for i in 1200:
		await get_tree().physics_frame
		if bruno._trip.is_empty():
			break
	var cafeteria := Rect2(Vector2(1, 35) * 16, Vector2(24, 11) * 16)
	check("llega a la cafeteria", cafeteria.has_point(bruno.global_position), bruno.global_position)
	player.global_position = Vector2(12, 39) * 16
	await frames(20)
	await shot("res://.godot/scene_lunch.png")
	WorkdayManager.clock = 200.0
	await frames(3)
	for i in 3000:
		await get_tree().physics_frame
		if bruno._trip.is_empty() and i > 30:
			break
	check("vuelve a su puesto", bruno.global_position.distance_to(desk) < 40.0, bruno.global_position.distance_to(desk))
	var carla: Npc = room.get_node("Entities/Npc_carla")
	check("los fijos no se mueven", not carla.follows_routine())
	check("los de ronda tampoco", not room.get_node("Entities/Npc_ramon").follows_routine())

	# Epílogos.
	StoryDirector.ending = "propio"
	StoryDirector.set_flag("secreto_lucia")
	Friends.change("lucia", 50)
	var epilogue: Control = (load("res://scenes/ui/epilogue.tscn") as PackedScene).instantiate()
	room.queue_free()
	room = null
	get_tree().root.add_child(epilogue)
	get_tree().current_scene = epilogue
	await frames(4)
	var slides: Array = epilogue.slides
	check("final propio", slides[0]["title"].contains("propia"), slides[0]["title"])
	var lucia_fate: Array = slides.filter(func(s: Dictionary) -> bool: return s.get("portrait", "") == "lucia")
	check("Lucia se queda contigo", not lucia_fate.is_empty() and lucia_fate[0]["text"].contains("rechazó"), lucia_fate)
	var ana_fate: Array = slides.filter(func(s: Dictionary) -> bool: return s.get("portrait", "") == "ana")
	check("Ana se fue contigo", not ana_fate.is_empty() and ana_fate[0]["text"].contains("se fue contigo"))
	check("Hugo espera juicio", slides.any(func(s: Dictionary) -> bool: return s.get("portrait", "") == "hugo" and s["text"].contains("juicio")))
	check("un destino por persona", slides.filter(func(s: Dictionary) -> bool: return s.get("portrait", "") == "ana").size() == 1)
	check("cierre", slides.back()["title"] == "FIN")
	await shot("res://.godot/scene_ending.png")
	epilogue.next_slide()
	await frames(2)
	await shot("res://.godot/scene_fate.png")
	StoryDirector.ending = "oscuro"
	check("final oscuro distinto", epilogue.build_slides()[0]["title"].contains("silencio"))
	for i in slides.size():
		epilogue.next_slide()
	await frames(10)
	check("vuelve al menu con partida nueva", get_tree().current_scene.name == "MainMenu" and StoryDirector.act == 1 and StoryDirector.ending == "")
	print("fallos: ", fails)
	get_tree().quit(1 if fails > 0 else 0)
