extends Node
## Comprueba selección de personaje y las maniobras propias de cada avería.
##
## Uso:  godot --path . res://tools/check_tasks.tscn

const VALID := ["timing", "hold", "pairs", "type", "screws", "pull", "wires", "ports"]

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


func type_text(text: String) -> void:
	for character in text:
		var e := InputEventKey.new()
		e.pressed = true
		e.unicode = character.unicode_at(0)
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		await frames(1)
		var up := InputEventKey.new()
		up.pressed = false
		Input.parse_input_event(up)
		Input.flush_buffered_events()
		await frames(1)


func shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path(path))


func _ready() -> void:
	CareerProfile.use_blank_profile()
	WorkdayManager.enabled = false
	EventDirector.enabled = false
	await get_tree().process_frame

	# Datos de las averías.
	var valid := true
	var combos := {}
	var typed_usb := 0
	for key: String in TicketManager.faults:
		var fault: Dictionary = TicketManager.faults[key]
		var actions: Array = fault.get("actions", [])
		valid = valid and actions.size() == fault["steps"].size()
		var signature := PackedStringArray()
		for step: Array in actions:
			valid = valid and step[0] in VALID
			signature.append(" ".join(step.map(func(v: Variant) -> String: return str(v))))
			if step[0] == "type":
				typed_usb += 1
				for character: String in str(step[1]):
					valid = valid and "abcdefghijklmnopqrstuvwxyz0123456789 .-".contains(character)
		combos[" / ".join(signature)] = key
	check("cada paso con maniobra valida", valid)
	check("averias con receta propia", combos.size() >= 24, "%d de %d" % [combos.size(), TicketManager.faults.size()])
	check("consola en las averias de software", typed_usb >= 25, typed_usb)
	var types := {}
	for fault: Dictionary in TicketManager.faults.values():
		for step: Array in fault["actions"]:
			types[step[0]] = true
	check("usa todas las maniobras", types.size() == VALID.size(), types.keys())
	for ticket: TicketData in TicketManager.catalog:
		if ticket.id == "pc_ana":
			check("primer ticket sencillo", ticket.fault == "cable_corriente" and ticket.tool == "kit")

	# Pantalla de personaje.
	var entry: Control = (load("res://scenes/ui/name_entry.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(entry)
	get_tree().current_scene = entry
	await frames(4)
	check("empieza por el nombre", entry.get_node("Panel").visible and not entry.get_node("Setup").visible)
	entry.submit_name("CHECO")
	await frames(2)
	check("pasa a la ficha", entry.get_node("Setup").visible and not entry.get_node("Panel").visible)
	await get_tree().create_timer(0.45).timeout
	await press("ui_right")
	check("elige mujer", entry.gender == "mujer", entry.gender)
	check("retrato de mujer", entry.get_node("%SetupPhoto").texture == load("res://assets/sprites/npc/portraits/alex_f.png"))
	await press("ui_down")
	await press("ui_accept")
	await press("ui_down")
	await press("ui_accept")
	await press("ui_down")
	await press("ui_accept")
	check("maximo dos rasgos", entry.chosen.size() == 2 and "temple" in entry.chosen and "agil" in entry.chosen, entry.chosen)
	await press("ui_up")
	await press("ui_accept")
	check("quitar rasgo", entry.chosen == ["temple"], entry.chosen)
	await press("ui_accept")
	await frames(2)
	await shot("res://.godot/setup.png")
	entry.row = CareerProfile.trait_catalog.size() + 1
	await press("ui_accept")
	await frames(8)
	check("sigue a la intro", get_tree().current_scene.name == "IntroCutscene", get_tree().current_scene)
	check("guardado", CareerProfile.gender == "mujer" and CareerProfile.traits == ["temple", "agil"], CareerProfile.traits)
	var hero_frame: AtlasTexture = get_tree().current_scene.get_node("Hero").texture
	check("intro con la protagonista", hero_frame.atlas == load(CareerProfile.SHEETS["mujer"]))
	check("texto en femenino", CareerProfile.format("{bienvenido}, {player}.") == "Bienvenida, CHECO.")
	get_tree().current_scene.queue_free()
	await frames(2)

	# Efectos de los rasgos.
	check("temple", is_equal_approx(Upgrades.stress_scale(), 0.9), Upgrades.stress_scale())
	check("paso ligero", is_equal_approx(Upgrades.speed_scale(), 1.08), Upgrades.speed_scale())
	var stress_before := GameState.stress
	GameState.add_stress(10.0)
	check("el rasgo baja el estres", is_equal_approx(GameState.stress - stress_before, 9.0), GameState.stress)
	GameState.stress = 0.0
	check("puesto en femenino", CareerProfile.title_of("Jefe de IT") == "Jefa de IT")
	check("hojas iguales", load(CareerProfile.SHEETS["mujer"]).get_size() == load(CareerProfile.SHEETS["hombre"]).get_size())

	# Oficina con la protagonista.
	var room: Node = (load("res://scenes/world/office.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(room)
	get_tree().current_scene = room
	await frames(8)
	var player: CharacterBody2D = room.get_node("Entities/Player")
	check("sprite de la protagonista", player.get_node("Sprite2D").texture == load(CareerProfile.SHEETS["mujer"]))
	check("retrato en el celular", room.get_node("Phone").get_node("%PhonePortrait").texture == load(CareerProfile.PORTRAITS["mujer"]))
	var bar: RepairBar = room.get_node("RepairBar")

	# Consola: compilación rota.
	var build: TicketData = TicketManager.next_for("lucia")
	TicketManager.accept(build)
	ToolBelt.selected = ToolBelt.Tool.USB
	var terminal: Terminal = room.get_node("Entities/Terminal_build_server")
	terminal.repair()
	await frames(2)
	check("consola abierta", bar._action is TypingAction and bar._action.command == "cat build.log", bar._kind)
	check("muestra el equipo", bar.get_node("%RepairIcon").visible)
	await type_text("cat")
	await frames(2)
	await shot("res://.godot/task_type.png")
	check("avanza al teclear", bar._action.typed == 3, bar._action.typed)
	var stress := GameState.stress
	await type_text("z")
	check("una errata no castiga", bar._action.typed == 3 and GameState.stress == stress)
	await type_text(" build.log")
	await frames(2)
	check("primer comando", TicketManager.repairs_done == 1 and bar._action.command == "npm ci", TicketManager.repairs_done)
	await type_text("npm ci")
	await frames(2)
	await type_text("make")
	await frames(16)
	check("compilacion arreglada", TicketManager.active == null and not bar.get_node("Panel").visible)

	# Tornillos: abrir un proyector.
	var video: TicketData = TicketManager.next_for("clara")
	TicketManager.accept(video)
	ToolBelt.selected = ToolBelt.Tool.KIT
	room.get_node("Entities/Terminal_proyector").repair()
	await frames(2)
	check("abre con tornillos", bar._action is ScrewsAction and bar._action.turns == 8, bar._kind)
	await shot("res://.godot/task_screws.png")
	await press("move_up")
	await press("move_right")
	check("gira en orden", bar._action.done == 2)
	var before := DayStats.misses
	await press("move_left")
	check("sentido equivocado falla", DayStats.misses == before + 1 and bar._action.done == 0)
	bar._close()
	await frames(12)
	TicketManager.reset()

	# Tirar: sacar una pieza sin romperla.
	var pull := PullAction.new()
	var results: Array = []
	pull.finished.connect(func(ok: bool) -> void: results.append(ok))
	pull.begin(null, 1.0)
	pull._holding = true
	for i in 240:
		pull.tick(1.0 / 60.0)
	check("pasarse rompe", results == [false], results)
	results.clear()
	pull = PullAction.new()
	pull.finished.connect(func(ok: bool) -> void: results.append(ok))
	pull.begin(null, 1.0)
	for i in 400:
		pull._holding = pull.tension < 0.6
		pull.tick(1.0 / 60.0)
		if not results.is_empty():
			break
	check("con cuidado sale", results == [true], results)

	# Hilos.
	var wires := WiresAction.new()
	results.clear()
	wires.finished.connect(func(ok: bool) -> void: results.append(ok))
	wires.begin(null, 1.0)
	for index: int in wires.order:
		var e := InputEventAction.new()
		e.action = "slot_%d" % (index + 1)
		e.pressed = true
		wires.handle(e)
	check("orden de hilos", results == [true], results)

	# Puertos.
	var ports := PortsAction.new()
	results.clear()
	ports.finished.connect(func(ok: bool) -> void: results.append(ok))
	ports.begin(null, 1.0)
	check("empieza fuera del puerto", ports.cursor != ports.dead)
	var strike := InputEventAction.new()
	strike.action = "attack"
	strike.pressed = true
	ports.handle(strike)
	ports.cursor = ports.dead
	ports.handle(strike)
	check("puerto correcto", results == [false, true], results)

	# Vistas de cada maniobra.
	for pair: Array in [["switch_core", "Terminal_switch", ToolBelt.Tool.TESTER, "ports"], ["refrigeracion", "Terminal_servidor", ToolBelt.Tool.KIT, "fan"]]:
		var ticket: TicketData = TicketManager.catalog.filter(func(t: TicketData) -> bool: return t.id == pair[0])[0]
		TicketManager.accept(ticket)
		ToolBelt.selected = pair[2]
		room.get_node("Entities/" + pair[1]).repair()
		await frames(3)
		await shot("res://.godot/task_%s.png" % pair[3])
		bar._close()
		await frames(14)
		TicketManager.reset()
	print("fallos: ", fails)
	get_tree().quit(1 if fails > 0 else 0)
