extends Node
## Comprueba que el bot empieza apagado, que F12 lo controla y que deja informe.
##
## Uso:  godot --path . res://tools/check_qa.tscn

const REPORT := "user://qa_prueba.txt"

var fails := 0


func check(label: String, ok: bool, info: Variant = "") -> void:
	if not ok:
		fails += 1
	print("%s %s %s" % ["OK  " if ok else "FAIL", label, info])


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func f12() -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = KEY_F12
		e.physical_keycode = KEY_F12
		e.pressed = down
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		await frames(2)


func _ready() -> void:
	CareerProfile.use_blank_profile()
	EventDirector.enabled = false
	WorkdayManager.enabled = false
	await get_tree().process_frame
	check("apagado por defecto", not QaBot.active)
	check("sin notas fuera del bot", not QaBot.log.enabled)
	QaBot.log.path = REPORT
	var room: Node = (load("res://scenes/world/office.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(room)
	get_tree().current_scene = room
	await frames(6)
	var player: Node2D = room.get_node("Entities/Player")
	var start := player.global_position
	await f12()
	check("F12 lo enciende", QaBot.active and QaBot.log.enabled)
	check("indicador visible", QaBot._overlay.visible)
	TicketManager.accept(TicketManager.next_for("bruno"))
	for i in 240:
		await get_tree().physics_frame
	check("toma el control", player.global_position.distance_to(start) > 30.0, player.global_position)
	await f12()
	check("F12 lo apaga", not QaBot.active and not QaBot._overlay.visible)
	check("suelta las teclas", not Input.is_action_pressed("move_left") and not Input.is_action_pressed("move_right") and not Input.is_action_pressed("move_up") and not Input.is_action_pressed("move_down"))
	check("deja informe", FileAccess.file_exists(REPORT))
	check("informe con datos", FileAccess.get_file_as_string(REPORT).contains("Tickets: aceptados"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(REPORT))
	print("fallos: ", fails)
	get_tree().quit(1 if fails > 0 else 0)
