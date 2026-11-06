extends Node
## Recorre la mecánica de la oficina: tickets, carrera, amonestaciones y despido.
##
## Uso:  godot --path . res://tools/check_office.tscn

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


func press_action(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	await tick(2)
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	await tick(2)


## Coloca al jugador junto al objetivo y pulsa interactuar.
func use(target: Node2D) -> void:
	player.global_position = target.global_position + Vector2(-16, -9)
	await tick(6)
	await press_action("interact")


func actor(name: String) -> Node2D:
	return room.get_node("Entities/" + name)


func _ready() -> void:
	CareerProfile.use_blank_profile()
	WorkdayManager.enabled = false
	TicketManager.skip_minigame = true
	EventDirector.enabled = false
	WorkdayManager.reputation_pace = 1.0
	await get_tree().process_frame
	room = (load("res://scenes/world/office.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(room)
	get_tree().current_scene = room
	player = room.get_node("Entities/Player")
	await tick(8)
	check("sin amonestaciones", GameState.warnings == 0, GameState.warning_name())
	check("puesto inicial", GameState.stage_title() == "Practicante de Soporte IT", GameState.stage_title())

	# Ticket completo: pedirlo, equivocarse de equipo y resolverlo.
	await use(actor("Npc_ana"))
	check("ticket aceptado", TicketManager.active != null and TicketManager.active.id == "pc_ana", TicketManager.active)
	await use(actor("Terminal_impresora"))
	await press_action("attack")
	await tick(26)
	check("equipo equivocado", TicketManager.active != null)
	await use(actor("Terminal_pc_ana"))
	await press_action("attack")
	await tick(26)
	check("ticket resuelto", TicketManager.active == null and GameState.reputation == 10, GameState.reputation)
	await use(actor("Npc_rrhh"))
	check("RR. HH. no abre tickets", TicketManager.active == null)

	# Ticket no resuelto a tiempo.
	await use(actor("Npc_bruno"))
	check("segundo ticket", TicketManager.active != null and TicketManager.active.target_id == "impresora", TicketManager.active)
	TicketManager.time_left = 0.01
	await tick(3)
	check("primera amonestacion", GameState.warnings == 1 and GameState.warning_name() == "Amonestación verbal", GameState.warning_name())
	check("penaliza reputacion", GameState.reputation == 5, GameState.reputation)

	# Carrera.
	GameState.add_reputation(95)
	check("jefe de IT", GameState.stage_title() == "Jefe de IT", GameState.reputation)
	GameState.add_reputation(10)
	check("gran tecnologica", GameState.stage_title() == "Ingeniero en Gran Tecnológica", GameState.reputation)
	GameState.add_reputation(500)
	check("empresa propia", GameState.stage_title() == "Fundador de su Empresa" and GameState.reputation == 200, GameState.reputation)
	await tick(2)
	var shot := get_tree().root.get_texture().get_image()
	shot.resize(shot.get_width() * 3, shot.get_height() * 3, Image.INTERPOLATE_NEAREST)
	shot.save_png(ProjectSettings.globalize_path("res://.godot/office_shot.png"))

	# Despido y reinicio.
	GameState.add_warning("prueba")
	check("segunda amonestacion", GameState.warning_name() == "Amonestación escrita", GameState.warning_name())
	GameState.add_warning("prueba")
	await tick(2)
	var panel: Control = room.get_node("GameOver/Panel")
	check("despido", GameState.warnings == 3 and get_tree().paused and panel.visible, GameState.warning_name())
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.godot/fired_shot.png"))
	await get_tree().create_timer(0.45, true, false, true).timeout
	var e := InputEventAction.new()
	e.action = "ui_accept"
	e.pressed = true
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	for i in 12:
		await get_tree().process_frame
	check("reinicio con liquidacion", GameState.warnings == 0 and GameState.reputation == 5.0 and ToolBelt.coffee == 4 and not get_tree().paused and TicketManager.active == null, "avisos=%d rep=%d" % [GameState.warnings, GameState.reputation])
	print("fallos: ", fails)
	get_tree().quit(1 if fails > 0 else 0)
