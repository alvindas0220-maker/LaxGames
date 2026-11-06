extends Node
## Comprueba reloj, cola, estrés, herramientas, minijuego, departamentos y música.
##
## Uso:  godot --path . res://tools/check_expansion.tscn

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


func act(action: String, down: bool) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = down
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	await tick(2)


func press(action: String) -> void:
	await act(action, true)
	await act(action, false)


func go_to(target: Node2D) -> void:
	player.global_position = target.global_position + Vector2(-16, -9)
	await tick(6)


func actor(node_name: String) -> Node2D:
	return room.get_node("Entities/" + node_name)


func shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path(path))


func _ready() -> void:
	CareerProfile.use_blank_profile()
	EventDirector.enabled = false
	TicketQueue.rng.seed = 5
	await get_tree().process_frame
	room = (load("res://scenes/world/office.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(room)
	get_tree().current_scene = room
	player = room.get_node("Entities/Player")
	await tick(8)
	var hud: Node = room.get_node("HUD")
	var bar: RepairBar = room.get_node("RepairBar")

	# Reloj, fase y música.
	check("reloj en marcha", WorkdayManager.running and WorkdayManager.clock_text() == "09:00", WorkdayManager.clock_text())
	WorkdayManager.clock = 150.0
	check("mediodia", WorkdayManager.clock_text() == "13:30", WorkdayManager.clock_text())
	WorkdayManager.clock = 0.0
	check("fase inicial", WorkdayManager.phase() == "Semana de Practicante", WorkdayManager.phase())
	var phone: Phone = room.get_node("Phone")
	phone.open(0)
	check("fase en el celular", phone.get_node("%ScreenText").text.contains("Semana de Practicante"))
	phone.close()
	check("musica sonando", AudioDirector.is_music_playing())
	AudioDirector._music.stop()
	await tick(3)
	check("la musica se recupera sola", AudioDirector.is_music_playing())
	var track: AudioStreamWAV = AudioDirector._music.stream
	check("musica en bucle", track.loop_mode == AudioStreamWAV.LOOP_FORWARD and track.get_length() > 30.0, track.get_length())

	# Departamentos.
	for id: String in ["diego", "ivan", "lucia", "tomas", "sofia"]:
		check("NPC " + id, actor("Npc_" + id) != null and NpcDatabase.portrait_of(id) != load(NpcDatabase.GENERIC_PORTRAIT))
	var departments := {}
	for id: String in NpcDatabase.ids():
		departments[NpcDatabase.get_npc(id)["department"]] = true
	check("cuatro departamentos IT", departments.has("Helpdesk") and departments.has("Infraestructura y Redes") and departments.has("Desarrollo") and departments.has("Jefatura de IT"), departments.keys())
	check("letreros", room.get_node("Signs").get_child_count() == 12)
	var tools := {}
	for ticket: TicketData in TicketManager.catalog:
		tools[ticket.tool] = true
		check("cadena valida " + ticket.id, ticket.chain.all(func(s: Dictionary) -> bool: return ToolBelt.TARGET_PLACES.has(s["target"]) and ToolBelt.TOOL_LABELS.has(s["tool"]))) if not ticket.chain.is_empty() else null
	check("tres herramientas en uso", tools.size() == 3, tools.keys())

	# Cola: Ana espera, el "!" se pinta y atenderla la saca de la cola.
	check("primer ticket en cola", TicketQueue.pending.has("ana"), TicketQueue.pending.keys())
	await tick(4)
	await shot("res://.godot/exp_queue.png")
	await go_to(actor("Npc_ana"))
	await shot("res://.godot/exp_mark.png")
	await press("interact")
	check("atender saca de la cola", not TicketQueue.pending.has("ana") and TicketManager.active != null and TicketManager.active.id == "pc_ana", TicketManager.active)
	var count_before := TicketQueue.pending.size()
	TicketQueue._timer = 0.0
	await tick(3)
	check("llegan tickets solos", TicketQueue.pending.size() == count_before + 1 and not TicketQueue.pending.has("ana"), TicketQueue.pending.keys())

	# Sin ticket en cola el NPC solo conversa.
	TicketQueue.reset()
	TicketQueue._timer = 999.0
	TicketManager.reset()
	await go_to(actor("Npc_bruno"))
	await press("interact")
	check("sin cola no hay ticket", TicketManager.active == null)

	# Caducar suma estrés y resta reputación, sin amonestación.
	GameState.add_reputation(20.0)
	var stress_before := GameState.stress
	TicketQueue.add("bruno")
	TicketQueue.pending["bruno"]["wait"] = 0.01
	await tick(3)
	check("caduca", not TicketQueue.pending.has("bruno") and GameState.stress >= stress_before + 15.0 and is_equal_approx(GameState.reputation, 19.0) and GameState.warnings == 0, GameState.reputation)

	# Esperar estresa.
	TicketQueue.reset()
	TicketQueue.add("diego")
	TicketQueue.add("lucia")
	GameState.stress = 0.0
	await get_tree().create_timer(1.0).timeout
	check("esperar estresa", GameState.stress > 0.1 and GameState.stress < 0.5, GameState.stress)
	await go_to(actor("Npc_lucia"))
	TicketQueue.pending["lucia"]["wait"] = 5.0
	await tick(3)
	await shot("res://.godot/exp_mark.png")
	TicketQueue.reset()
	TicketQueue._timer = 999.0

	# Herramienta equivocada.
	GameState.stress = 0.0
	TicketManager.accept(TicketManager.next_for("ana"))
	await go_to(actor("Terminal_pc_ana"))
	await press("slot_4")
	await press("attack")
	await tick(26)
	check("herramienta equivocada", TicketManager.active != null and not TicketManager.repairing and is_equal_approx(GameState.stress, 3.0), GameState.stress)
	check("dice cual falta", hud.get_node("%DialogLabel").text.contains("kit"), hud.get_node("%DialogLabel").text)

	# Kit: minijuego de cursor.
	await press("slot_1")
	await press("attack")
	check("abre el minijuego", TicketManager.repairing and bar.get_node("Panel").visible)
	var pos := player.global_position
	await act("move_right", true)
	await tick(10)
	await act("move_right", false)
	check("el jugador no se mueve", player.global_position == pos)
	await shot("res://.godot/exp_kit.png")
	bar._zone = Vector2(0.0, 0.0)
	bar._position = 0.5
	await press("attack")
	check("fallo fuera de la zona", TicketManager.active != null and GameState.stress > 3.0 and bar.get_node("Panel").visible, GameState.stress)
	bar._zone = Vector2(0.0, 1.0)
	await press("attack")
	await tick(12)
	check("acierto repara", TicketManager.active == null and not bar.get_node("Panel").visible and not TicketManager.repairing)
	await tick(26)

	# USB: mantener y soltar.
	var correo := TicketManager.next_for("ana")
	check("correo pide USB", correo.tool == "usb", correo.tool)
	TicketManager.accept(correo)
	await go_to(actor("Terminal_servidor"))
	await press("slot_3")
	await press("attack")
	check("abre con USB", bar._tool == "usb" and bar._kind == "hold" and bar.get_node("Panel").visible, bar._kind)
	await tick(30)
	bar._zone = Vector2(0.0, 1.0)
	await act("attack", true)
	await tick(10)
	check("la barra se llena", bar._position > 0.0, bar._position)
	await shot("res://.godot/exp_usb.png")
	await act("attack", false)
	check("soltar cuenta", TicketManager.repairs_done == 1, TicketManager.repairs_done)
	bar._zone = Vector2(0.0, 1.0)
	await act("attack", true)
	await tick(6)
	await act("attack", false)
	await tick(12)
	check("USB resuelve", TicketManager.active == null)
	await tick(26)

	# Tester y ticket encadenado: dos equipos y dos herramientas.
	var chained: TicketData
	for ticket: TicketData in TicketManager.catalog:
		if ticket.id == "bucle_red":
			chained = ticket
	GameState.stress = 0.0
	TicketManager.accept(chained)
	await go_to(actor("Terminal_switch"))
	await press("slot_4")
	await press("attack")
	check("abre con tester", bar._tool == "tester", bar._tool)
	await tick(4)
	await shot("res://.godot/exp_tester.png")
	await press(RepairBar.PAIR_ACTIONS[(bar._pair + 1) % 4])
	check("par equivocado", TicketManager.repairs_done == 0 and GameState.stress > 0.0)
	await press(RepairBar.PAIR_ACTIONS[bar._pair])
	check("par correcto", TicketManager.repairs_done == 1)
	await press(RepairBar.PAIR_ACTIONS[bar._pair])
	await tick(12)
	check("pasa al segundo equipo", TicketManager.active == chained and TicketManager.stage == 1 and TicketManager.current_target() == "router", TicketManager.current_target())
	await tick(26)
	TicketManager.reset()

	# Cancelar deja el ticket abierto.
	TicketManager.accept(TicketManager.next_for("ana"))
	await go_to(actor("Terminal_pc_ana"))
	await press("slot_1")
	await press("attack")
	await press("interact")
	await tick(12)
	check("cancelar", TicketManager.active != null and not TicketManager.repairing and not bar.get_node("Panel").visible)
	TicketManager.reset()

	# Jornada incumplida y semana limpia.
	GameState.add_warning("prueba")
	await tick(40)
	DayStats.solved = 1
	WorkdayManager.closed_today = 1
	WorkdayManager.clock = 9999.0
	await tick(3)
	check("cuota incumplida amonesta", GameState.warnings == 2 and room.get_node("DaySummary/Panel").visible, GameState.warnings)
	await shot("res://.godot/exp_summary.png")
	get_tree().paused = false
	room.get_node("DaySummary/Panel").hide()
	var coffee := ToolBelt.coffee
	GameState.stress = 50.0
	WorkdayManager.next_day()
	check("descanso y cafe", is_equal_approx(GameState.stress, 20.0) and ToolBelt.coffee == coffee + 1, GameState.stress)
	WorkdayManager._warned_this_week = false
	WorkdayManager.day = 5
	WorkdayManager.next_day()
	check("semana limpia", GameState.warnings == 1 and WorkdayManager.morning_note.contains("amonestación"), GameState.warnings)
	check("mas presion", WorkdayManager.spawn_interval() < 34.0 and WorkdayManager.quota() == 6, WorkdayManager.spawn_interval())

	# Vistas de cada ala.
	WorkdayManager.running = false
	TicketQueue.reset()
	for cell: Vector2i in [Vector2i(54, 6), Vector2i(54, 21), Vector2i(34, 6), Vector2i(10, 6)]:
		player.global_position = Vector2(cell * 16)
		await tick(30)
		await shot("res://.godot/exp_room_%d_%d.png" % [cell.x, cell.y])
	print("fallos: ", fails)
	get_tree().quit(1 if fails > 0 else 0)
