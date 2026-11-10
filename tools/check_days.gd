extends Node
## Comprueba días temáticos, pausas con charla y conversaciones de pasillo.
##
## Uso:  godot --path . res://tools/check_days.tscn

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


func close_panels() -> void:
	for path: String in ["EpisodeCard/Panel", "EventPanel/Panel"]:
		room.get_node(path).hide()
	get_tree().paused = false


func _ready() -> void:
	CareerProfile.use_blank_profile()
	StoryDirector.enabled = true
	EventDirector.enabled = false
	TicketQueue.rng.seed = 4
	await get_tree().process_frame

	# Datos: tickets, oradores y zonas existen.
	var data := DayEvents.data()
	var ids := {}
	for ticket: TicketData in TicketManager.catalog:
		ids[ticket.id] = true
	var valid := true
	for entry: Dictionary in data["themed_days"] + data["weekday_themes"]:
		for beat: Dictionary in entry.get("beats", []):
			for id: String in beat.get("tickets", []):
				valid = valid and ids.has(id)
			if beat.has("event"):
				valid = valid and NpcDatabase.has_npc(beat["event"]["speaker"])
	check("tickets y oradores de los dias", valid)
	check("diez dias guionizados", data["themed_days"].size() >= 10)
	var themes := {}
	for day in range(1, 31):
		themes[DayEvents.theme_for(day).get("id", "")] = true
	check("todos los dias tienen tema", not themes.has(""), themes.keys().size())
	for talk: Dictionary in data["overheard"]:
		for line: Array in talk["lines"]:
			valid = valid and NpcDatabase.has_npc(line[0])
		if talk.has("clue"):
			valid = valid and StoryDirector.clue_catalog().has(talk["clue"])
	check("conversaciones de pasillo validas", valid)

	room = (load("res://scenes/world/office.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(room)
	get_tree().current_scene = room
	await frames(6)

	# Día 1: bienvenida.
	check("tema del dia 1", DayEvents.title() == "Día de bienvenida", DayEvents.title())
	check("tema en el episodio", room.get_node("EpisodeCard").get_node("%EpisodeTheme").text.contains("bienvenida"))
	await shot("res://.godot/days_card.png")
	check("cuota mas suave", WorkdayManager.quota() == 4, WorkdayManager.quota())
	close_panels()
	await frames(3)
	WorkdayManager.clock = 0.06 * 330.0
	await frames(3)
	check("momento programado", room.get_node("HUD").get_node("%DialogLabel").text.contains("cafetera"))

	# Día 2: auditoría.
	WorkdayManager.day = 2
	DayEvents.start_day()
	check("auditoria", DayEvents.title() == "Auditoría sorpresa" and DayEvents.mod("tool_error", 1.0) == 2.0)
	GameState.stress = 0.0
	TicketManager.accept(TicketManager.next_for("ana"))
	TicketManager.try_repair(TicketManager.current_target(), "usb")
	check("errores al doble con estres extra", is_equal_approx(GameState.stress, TicketManager.WRONG_TOOL_STRESS * 2.0 * 1.15), GameState.stress)
	GameState.reputation = 0.0
	TicketManager.resolve(TicketManager.current_target())
	await frames(2)
	check("aciertos valen mas", GameState.reputation > 10.0 * WorkdayManager.reputation_pace * 1.2, GameState.reputation)

	# Día 3: caída de Desarrollo con tickets forzados.
	WorkdayManager.day = 3
	DayEvents.start_day()
	TicketQueue.reset()
	TicketQueue._timer = 999.0
	WorkdayManager.clock = 0.27 * 330.0
	await frames(3)
	check("tickets de la caida", TicketQueue.pending.has("lucia") and TicketQueue.pending["lucia"]["ticket"].id == "build_roto" and TicketQueue.pending.has("tomas"), TicketQueue.pending.keys())

	# Día 4: cumpleaños en el almuerzo.
	WorkdayManager.day = 4
	DayEvents.start_day()
	WorkdayManager.clock = 150.0
	WorkdayManager.lunch_taken = false
	GameState.stress = 60.0
	TicketManager.reset()
	room.get_node("Entities/LunchTable").interact()
	await frames(2)
	var panel: Control = room.get_node("EventPanel/Panel")
	check("almuerzo de cumpleanos", panel.visible and room.get_node("EventPanel")._event["id"] == "cumpleanos_ana")
	await shot("res://.godot/days_birthday.png")
	await wait_guard()
	await press("ui_accept")
	await frames(2)
	check("chisme del cumpleanos", StoryDirector.has_clue("pagos_ana") and GameState.stress < 60.0, GameState.stress)

	# Cafetera: pausa, charla exclusiva y límite.
	var machine: CoffeeMachine = room.get_node("Entities/CoffeeMachine")
	GameState.stress = 50.0
	machine.interact()
	await frames(2)
	check("cafe en el almuerzo relaja", is_equal_approx(GameState.stress, 50.0 - CoffeeMachine.RELIEF * 2.0), GameState.stress)
	check("charla de cafetera", panel.visible and room.get_node("EventPanel")._event.get("id", "").begins_with("cafe_"))
	await shot("res://.godot/days_coffee.png")
	await wait_guard()
	await press("ui_accept")
	await frames(2)
	var stress := GameState.stress
	machine.interact()
	check("no se abusa", is_equal_approx(GameState.stress, stress))

	# Sofá en el almuerzo: charla de la vida cotidiana.
	var sofa: Amenity = room.get_node("Entities/Amenity_27_42")
	sofa.interact()
	await frames(2)
	check("charla en el descanso", panel.visible and room.get_node("EventPanel")._event.get("id", "").begins_with("descanso_"))
	close_panels()

	# Cafetera rota el día 9.
	WorkdayManager.day = 9
	DayEvents.start_day()
	machine._ready_at = -INF
	stress = GameState.stress
	machine.interact()
	check("sin cafe ese dia", is_equal_approx(GameState.stress, stress) and room.get_node("HUD").get_node("%DialogLabel").text.contains("rota"))

	# Conversación de pasillo al pasar.
	WorkdayManager.day = 2
	var player: CharacterBody2D = room.get_node("Entities/Player")
	var zone: Node2D = room.get_node("Entities/Overhear_banos")
	player.global_position = zone.global_position + Vector2(0, 60)
	await frames(6)
	player.global_position = zone.global_position
	for i in 6:
		await get_tree().physics_frame
	await frames(2)
	check("se oye al pasar", Overheard.playing.get("id", "") == "oye_banos_hugo", Overheard.playing.get("id", ""))
	var dialog: Label = room.get_node("HUD").get_node("%DialogLabel")
	check("frase de fondo", dialog.text.begins_with("(De fondo)") and dialog.text.contains("Hugo"), dialog.text)
	check("no pausa el juego", not get_tree().paused)
	await shot("res://.godot/days_overheard.png")
	await get_tree().create_timer(Overheard.LINE_SECONDS * 3.5).timeout
	check("termina la charla", Overheard.playing.is_empty())
	check("no se repite en seguida", not Overheard.overhear("banos"))

	# Una conversación de pasillo puede dar una pista.
	Overheard._cooldown.clear()
	WorkdayManager.day = 5
	check("pista oida", Overheard.overhear("gerencia"))
	await get_tree().create_timer(Overheard.LINE_SECONDS * 2.5).timeout
	check("pista registrada", StoryDirector.has_clue("cunado_bruno"))
	print("fallos: ", fails)
	get_tree().quit(1 if fails > 0 else 0)
