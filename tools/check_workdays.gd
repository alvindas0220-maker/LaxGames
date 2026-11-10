extends Node
## Comprueba jornadas, eventos, final, retrato de reserva y duración estimada.
##
## Uso:  godot --path . res://tools/check_workdays.tscn

const FIXTURE := "user://npcs_portrait.json"

var fails := 0


func check(label: String, ok: bool, info: Variant = "") -> void:
	if not ok:
		fails += 1
	print("%s %s %s" % ["OK  " if ok else "FAIL", label, info])


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func send(action: String) -> void:
	for down in [true, false]:
		var e := InputEventAction.new()
		e.action = action
		e.pressed = down
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		await frames(2)


func shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path(path))


func close_ticket(npc_id: String) -> void:
	var ticket := TicketManager.next_for(npc_id)
	TicketManager.accept(ticket)
	TicketManager.resolve(ticket.target_id)
	await frames(3)


func _ready() -> void:
	await get_tree().process_frame
	CareerProfile.use_blank_profile()
	EventDirector.enabled = false
	var room: Node = (load("res://scenes/world/office.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(room)
	get_tree().current_scene = room
	await frames(6)
	check("primera jornada", WorkdayManager.label() == "Semana 1, día 1" and WorkdayManager.quota() == 5, WorkdayManager.label())
	var day_label: Label = room.get_node("HUD").get_node("%DayLabel")
	check("jornada en HUD", day_label.text.contains("0/5"), day_label.text)

	await close_ticket("ana")
	check("reputacion con ritmo", is_equal_approx(GameState.reputation, 10.0 * WorkdayManager.reputation_pace), GameState.reputation)
	check("jornada sigue", not get_tree().paused and WorkdayManager.closed_today == 1)
	for i in 5:
		await close_ticket("bruno")
	check("cuota cumplida no corta el dia", WorkdayManager.running and not get_tree().paused, WorkdayManager.closed_today)
	var rep_end := GameState.reputation
	WorkdayManager.clock = 9999.0
	await frames(3)
	var summary: Control = room.get_node("DaySummary/Panel")
	check("fin de jornada por reloj", summary.visible and get_tree().paused and GameState.warnings == 0)
	await frames(2)
	await shot("res://.godot/day_summary.png")
	await get_tree().create_timer(0.45, true, false, true).timeout
	await send("ui_accept")
	await frames(3)
	check("pasa a la noche", room.get_node("NightMenu/Panel").visible and get_tree().paused and GameState.night)
	await shot("res://.godot/night_menu.png")
	room.get_node("NightMenu").sleep()
	await frames(10)
	room = get_tree().current_scene
	check("siguiente jornada", WorkdayManager.day == 2 and WorkdayManager.closed_today == 0 and is_equal_approx(GameState.reputation, rep_end) and not get_tree().paused, WorkdayManager.label())
	check("el reloj vuelve a empezar", WorkdayManager.running and WorkdayManager.clock < 5.0, WorkdayManager.clock)
	WorkdayManager.day = 6
	check("cuota crece", WorkdayManager.quota() == 6 and WorkdayManager.label() == "Semana 2, día 1", WorkdayManager.quota())
	WorkdayManager.day = 2

	# Evento: panel, elección y efecto.
	var chosen: Array = []
	EventDirector.event_started.connect(func(e: Dictionary) -> void: chosen.append(e), CONNECT_ONE_SHOT)
	EventDirector.trigger()
	await frames(2)
	var panel: Control = room.get_node("EventPanel/Panel")
	var options: Label = room.get_node("EventPanel").get_node("%EventOptions")
	check("evento pausa", panel.visible and get_tree().paused, chosen[0]["id"])
	await shot("res://.godot/event_panel.png")
	await send("move_down")
	check("cambia opcion", options.text.split("\n")[1].begins_with(">"), options.text)
	var option: Dictionary = chosen[0]["options"][1]
	var rep_before := GameState.reputation
	await get_tree().create_timer(0.45, true, false, true).timeout
	await send("ui_accept")
	await frames(2)
	check("aplica la opcion", not panel.visible and not get_tree().paused and is_equal_approx(GameState.reputation, clampf(rep_before + float(option.get("reputation", 0)) * WorkdayManager.event_pace(), 0.0, 200.0)), option["label"])
	var dialog: Label = room.get_node("HUD").get_node("%DialogLabel")
	check("responde el personaje", dialog.text.contains(option["reply"]), dialog.text)

	# Todos los eventos pueden salir y los datos son válidos.
	var seen := {}
	EventDirector.event_started.connect(func(e: Dictionary) -> void: seen[e["id"]] = true)
	for i in 300:
		EventDirector.rng.seed = i
		EventDirector.trigger()
		get_tree().paused = false
		room.get_node("EventPanel/Panel").hide()
	check("variedad de eventos", seen.size() == 14, seen.size())
	for id: String in ["clara", "bruno", "ana", "rrhh", "ivan", "lucia", "diego", "sofia"]:
		check("orador %s" % id, NpcDatabase.has_npc(id))

	# Retrato genérico para datos incompletos.
	WorkdayManager.running = false
	TicketQueue.reset()
	var entries := [
		{"id": "sin_campo", "name": "A", "department": "B", "role": "soporte", "sprite_frame": 0, "dialogue": "Hola"},
		{"id": "ruta_mala", "name": "C", "department": "B", "role": "soporte", "portrait": "res://no/existe.png", "sprite_frame": 0, "dialogue": "Hola"},
	]
	var file := FileAccess.open(FIXTURE, FileAccess.WRITE)
	file.store_string(JSON.stringify({"npcs": entries}))
	file.close()
	check("acepta NPC sin retrato", NpcDatabase.load_from(FIXTURE) == 2)
	var generic: Texture2D = load(NpcDatabase.GENERIC_PORTRAIT)
	check("retrato generico", generic != null and NpcDatabase.portrait_of("sin_campo") == generic and NpcDatabase.portrait_of("ruta_mala") == generic)
	DialogueManager.speak("ruta_mala", "Prueba")
	await frames(2)
	var portrait: TextureRect = room.get_node("HUD").get_node("%SpeakerPortrait")
	check("dialogo sin fallar", portrait.visible and portrait.texture == generic)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE))
	NpcDatabase.load_from(NpcDatabase.DATA_PATH)

	# Duración estimada con los tickets reales.
	var reward := 0.0
	var fair := 0
	for ticket: TicketData in TicketManager.catalog:
		reward += ticket.reputation * float(NpcDatabase.rules_of(ticket.requester_id)["reputation_scale"]) * WorkdayManager.reputation_pace
		fair += 1
	var per_ticket := reward / fair
	var days := [0, 0]
	var pace_rep := 0.0
	WorkdayManager.day = 1
	var total_days := 0
	while pace_rep < 200.0:
		total_days += 1
		WorkdayManager.day = total_days
		pace_rep += per_ticket * WorkdayManager.quota()
		if days[0] == 0 and pace_rep >= 100.0:
			days[0] = total_days
	days[1] = total_days
	print("duracion: %.2f por ticket, 100%% en dia %d, 200%% en dia %d" % [per_ticket, days[0], days[1]])
	check("arco largo", days[0] >= 12 and days[1] >= 25 and days[1] <= 50, days)
	WorkdayManager.day = 2

	# Final de la historia.
	GameState.reputation = 200
	await close_ticket("clara")
	WorkdayManager.closed_today = 0
	WorkdayManager._end_day()
	await frames(2)
	var text: Label = room.get_node("DaySummary").get_node("%SummaryLabel")
	check("final", text.text.begins_with("FIN DE LA HISTORIA"), text.text.substr(0, 30))
	await get_tree().create_timer(0.45, true, false, true).timeout
	await send("ui_accept")
	await frames(12)
	check("partida nueva", get_tree().current_scene.name == "MainMenu" and GameState.reputation == 0 and WorkdayManager.day == 1, get_tree().current_scene.name)
	print("fallos: ", fails)
	get_tree().quit(1 if fails > 0 else 0)
