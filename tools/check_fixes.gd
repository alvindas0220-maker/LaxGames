extends Node
## Evita que reaparezcan los fallos B1 a B4 de la auditoría de QA.
##
## Uso:  godot --path . res://tools/check_fixes.tscn

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


func key(code: int) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		await tick(1)


func wait_real(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _ready() -> void:
	WorkdayManager.enabled = false
	EventDirector.enabled = false
	await get_tree().process_frame
	room = (load("res://scenes/world/office.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(room)
	get_tree().current_scene = room
	player = room.get_node("Entities/Player")
	await tick(8)
	var interactor: Interactor = player.get_node("Interactor")

	# B1: el objetivo sigue al jugador y el kit encuentra el equipo del ticket.
	var terminal: Terminal = room.get_node("Entities/Terminal_proyector")
	var clara: Npc = room.get_node("Entities/Npc_clara")
	clara.set_physics_process(false)
	clara.global_position = terminal.global_position + Vector2(30, 0)
	await tick(3)
	player.global_position = clara.global_position + Vector2(6, -16)
	await tick(6)
	check("B1 empieza junto al NPC", interactor._target != null and interactor._target.get_parent() is Npc)
	var goal := terminal.global_position + Vector2(10, -16)
	for i in 60:
		player.global_position = player.global_position.move_toward(goal, 1.0)
		await tick(1)
	check("B1 objetivo actualizado", interactor._target == terminal, interactor._target)
	player.global_position = terminal.global_position + Vector2(18, -9)
	await tick(6)
	check("B1 dentro de ambos alcances, NPC mas cerca", interactor.get_overlapping_areas().size() == 2 and interactor._target != terminal, interactor.get_overlapping_areas().size())
	TicketManager.accept(TicketManager.next_for("clara"))
	await key(KEY_SPACE)
	await tick(26)
	check("B1 el kit repara con un NPC mas cerca", TicketManager.active == null, TicketManager.active)
	TicketManager.reset()
	clara.set_physics_process(true)
	player.global_position = Vector2(100, 230)
	await tick(30)

	# B2: un evento pendiente espera a que se cierre el ticket.
	var fired := [0]
	var count := func(_e: Dictionary) -> void: fired[0] += 1
	EventDirector.event_started.connect(count)
	EventDirector._timer = 0.2
	TicketManager.accept(TicketManager.next_for("ana"))
	await tick(30)
	check("B2 no interrumpe un ticket", fired[0] == 0)
	TicketManager.reset()
	await tick(3)
	check("B2 sale al cerrar el ticket", fired[0] == 1, fired[0])

	# B3: el evento recién abierto no se cierra con Espacio ni al instante.
	var panel: Control = room.get_node("EventPanel/Panel")
	check("B3 evento abierto", panel.visible and get_tree().paused)
	await key(KEY_ENTER)
	check("B3 ignora Enter inmediato", panel.visible)
	await wait_real(0.45)
	await key(KEY_SPACE)
	check("B3 ignora Espacio", panel.visible)
	await key(KEY_ENTER)
	check("B3 Enter confirma", not panel.visible and not get_tree().paused)
	EventDirector.event_started.disconnect(count)

	# B4: mensajes de cambio de puesto.
	var messages: Array[String] = []
	GameState.notice.connect(func(t: String) -> void: messages.append(t))
	GameState.reset()
	GameState.reputation = 45
	GameState.add_reputation(5)
	check("B4 sube", messages.back() == "Ascenso: Técnico de Soporte IT", messages)
	GameState.add_reputation(-5)
	check("B4 baja", messages.back() == "Descenso: Junior de Soporte IT", messages)
	print("fallos: ", fails)
	get_tree().quit(1 if fails > 0 else 0)
