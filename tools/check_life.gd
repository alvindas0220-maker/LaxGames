extends Node
## Comprueba almuerzo, amistades, desahogo, episodios y equilibrio social.
##
## Uso:  godot --path . res://tools/check_life.tscn

var fails := 0


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


func _ready() -> void:
	CareerProfile.use_blank_profile()
	StoryDirector.enabled = true
	EventDirector.enabled = false
	TicketQueue.rng.seed = 2
	await get_tree().process_frame
	var room: Node = (load("res://scenes/world/office.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(room)
	get_tree().current_scene = room
	await frames(6)

	# Episodio de la mañana.
	var card: Control = room.get_node("EpisodeCard/Panel")
	check("episodio al empezar", card.visible and get_tree().paused)
	check("titulo del episodio", room.get_node("EpisodeCard").get_node("%EpisodeTitle").text == "El primer día", room.get_node("EpisodeCard").get_node("%EpisodeTitle").text)
	check("rumor del dia", room.get_node("EpisodeCard").get_node("%EpisodeRumor").text.begins_with("Dicen"))
	await shot("res://.godot/life_episode.png")
	await wait_guard()
	await press("ui_accept")
	check("empieza la jornada", not card.visible and not get_tree().paused)

	# Datos.
	for node: Dictionary in StoryDirector.gossip_nodes().values():
		for option: Dictionary in node["options"]:
			if option.has("next") and not StoryDirector.gossip_nodes().has(option["next"]):
				check("siguiente valido " + node["id"], false)
	var talkers := {}
	for node: Dictionary in StoryDirector.gossip_nodes().values():
		if node["requires"].has("friend_min") if node.has("requires") else false:
			talkers[node["speaker"]] = true
	check("vida personal de muchos", talkers.size() >= 10, talkers.keys())

	# Almuerzo: se detienen la cola y los plazos.
	var cola_timer := 999.0
	TicketQueue.reset()
	TicketQueue._timer = cola_timer
	TicketQueue.add("bruno")
	var wait_before: float = TicketQueue.pending["bruno"]["wait"]
	TicketManager.accept(TicketManager.next_for("ana"))
	WorkdayManager.clock = 150.0
	await frames(3)
	var time_before := TicketManager.time_left
	GameState.stress = 40.0
	await get_tree().create_timer(0.5).timeout
	check("hora de almuerzo", WorkdayManager.in_lunch(), WorkdayManager.clock_text())
	check("no corre la espera", is_equal_approx(TicketQueue.pending["bruno"]["wait"], wait_before) and is_equal_approx(TicketManager.time_left, time_before))
	check("no sube el estres", is_equal_approx(GameState.stress, 40.0), GameState.stress)
	check("almuerzo en HUD", room.get_node("HUD").get_node("%DayLabel").text.contains("Almuerzo"), room.get_node("HUD").get_node("%DayLabel").text)
	TicketManager.reset()
	await frames(2)

	# Comer con alguien.
	var table: LunchTable = room.get_node("Entities/LunchTable")
	var panel: Control = room.get_node("EventPanel/Panel")
	table.interact()
	await frames(2)
	check("elige compañia", panel.visible and room.get_node("EventPanel")._event["options"].size() == 4)
	await shot("res://.godot/life_lunch.png")
	var option: Dictionary = room.get_node("EventPanel")._event["options"][0]
	await wait_guard()
	await press("ui_accept")
	await frames(2)
	check("comer relaja", is_equal_approx(GameState.stress, 25.0), GameState.stress)
	check("comer une", Friends.value_of(option["friend_id"]) == LunchTable.LUNCH_FRIEND, Friends.value_of(option["friend_id"]))
	table.interact()
	await frames(2)
	check("un almuerzo al dia", not panel.visible)
	WorkdayManager.clock = 10.0
	await frames(2)
	table.interact()
	await frames(2)
	check("fuera de hora no abre", not panel.visible and room.get_node("HUD").get_node("%DialogLabel").text.contains("13:00"))

	# Conversación ramificada con vida personal.
	TicketQueue.reset()
	TicketQueue._timer = 999.0
	WorkdayManager.day = 2
	StoryDirector._seen["ana_facturas"] = true
	var ana: Npc = room.get_node("Entities/Npc_ana")
	ana.interact()
	await frames(3)
	var panel_script: Node = room.get_node("EventPanel")
	check("cuenta su vida", panel.visible and panel_script.get_node("%EventText").text.contains("hija"), panel_script.get_node("%EventText").text)
	await shot("res://.godot/life_talk.png")
	await wait_guard()
	await press("ui_accept")
	await frames(2)
	check("rama personal", panel.visible and panel_script.get_node("%EventText").text.contains("Sara"), panel_script.get_node("%EventText").text)
	await wait_guard()
	await press("ui_accept")
	await frames(2)
	check("sube la amistad", Friends.value_of("ana") >= 20 and Friends.tier_name("ana") == "Compañero", Friends.value_of("ana"))
	check("una charla al dia", StoryDirector.next_gossip("ana").is_empty())

	# Desahogo con un amigo.
	WorkdayManager.day = 3
	GameState.stress = 50.0
	ana.interact()
	await frames(3)
	check("ofrece desahogarse", panel.visible and panel_script._event["id"] == "desahogo", panel_script._event.get("id"))
	await wait_guard()
	await press("ui_accept")
	await frames(2)
	check("desahogarse relaja", is_equal_approx(GameState.stress, 43.0), GameState.stress)

	# Niveles, confidente y su efecto.
	Friends.change("ana", 100)
	check("confidente", Friends.tier_name("ana") == "Confidente")
	check("confidente amortigua", Friends.stress_scale() < 1.0, Friends.stress_scale())
	check("pista por amistad", StoryDirector.next_gossip("ana").get("id", "") == "ana_confidente" or StoryDirector.talked_today("ana"))
	check("evento por amistad", StoryDirector.is_available({"friends_min": {"ana": 50}}))
	check("sin amistad no sale", not StoryDirector.is_available({"friends_min": {"lucia": 50}}))
	var phone: Phone = room.get_node("Phone")
	phone.open(Phone.FRIENDS_TAB)
	await frames(2)
	check("amigos en el celular", phone.get_node("%ScreenText").text.contains("Ana: Confidente"), phone.get_node("%ScreenText").text)
	await shot("res://.godot/life_phone.png")
	phone.close()

	# Equilibrio: socializar descansa, aislarse pesa.
	Friends.social_today = 2
	GameState.stress = 80.0
	var day := WorkdayManager.day
	WorkdayManager.next_day()
	check("socializar descansa mas", GameState.stress < 80.0 - 30.0, GameState.stress)
	WorkdayManager.day = day
	Friends.social_today = 0
	for i in Friends.LONELY_DAYS:
		GameState.stress = 80.0
		WorkdayManager.next_day()
	check("aislarse pesa", Friends.is_lonely() and GameState.stress > 80.0 - 30.0, GameState.stress)
	check("aviso de soledad", WorkdayManager.morning_note.contains("soledad"), WorkdayManager.morning_note)

	# Episodios según la trama.
	StoryDirector.clues["factura_nexo"] = true
	check("episodio de la trama", StoryDirector.episode_today()["title"] == "La factura")
	check("no se repite", StoryDirector.episode_today()["title"] != "La factura")
	StoryDirector.set_flag("confia_sofia")
	check("reacciona a decisiones", StoryDirector.episode_today()["title"] == "Un pacto en Jefatura")
	print("fallos: ", fails)
	get_tree().quit(1 if fails > 0 else 0)
