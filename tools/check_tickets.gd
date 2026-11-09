extends Node
## Comprueba el catálogo de tickets y que reparar exija el kit.
##
## Uso:  godot --path . res://tools/check_tickets.tscn

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


func go_to(target: Node2D) -> void:
	player.global_position = target.global_position + Vector2(-16, -9)
	await tick(6)


func strike() -> void:
	await press("attack")
	await tick(26)


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

	# Catálogo.
	var catalog: Array = TicketManager.catalog
	check("65 tickets", catalog.size() == 65, catalog.size())
	var ids := {}
	var valid := true
	var targets := {}
	for node in room.get_node("Entities").get_children():
		if node is Terminal:
			targets[node.target_id] = true
	for ticket: TicketData in catalog:
		ids[ticket.id] = true
		valid = valid and NpcDatabase.has_npc(ticket.requester_id) and targets.has(ticket.target_id) and ToolBelt.TARGET_PLACES.has(ticket.target_id) and ticket.repairs >= 1
	check("ids unicos", ids.size() == catalog.size(), ids.size())
	check("NPC y equipos existen", valid)
	WorkdayManager.day = 1
	var early := 0
	for ticket: TicketData in catalog:
		if ticket.min_day <= 1:
			early += 1
	check("empieza con pocos", early == 9, early)
	check("primer ticket de Ana", TicketManager.next_for("ana").id == "pc_ana")
	check("procedimiento completo", TicketManager.catalog.filter(func(t: TicketData) -> bool: return t.id == "nomina")[0].repairs == 4)
	WorkdayManager.day = 20
	var seen := {}
	for i in 8:
		var ticket := TicketManager.next_for("clara")
		seen[ticket.id] = true
		TicketManager.accept(ticket)
		TicketManager.resolve(ticket.target_id)
	check("rota por todo el catalogo", seen.size() == 8, seen.size())
	TicketManager.reset()
	GameState.reset()
	WorkdayManager.day = 1

	# El kit es obligatorio.
	var terminal: Terminal = room.get_node("Entities/Terminal_pc_ana")
	var dialog: Label = room.get_node("HUD").get_node("%DialogLabel")
	TicketManager.accept(TicketManager.next_for("ana"))
	await go_to(terminal)
	await press("interact")
	check("E no repara", TicketManager.active != null and dialog.text.contains("kit"), dialog.text)
	await press("slot_2")
	await strike()
	check("otra ranura no repara", TicketManager.active != null)
	await press("slot_1")
	await strike()
	check("el kit repara", TicketManager.active == null and GameState.reputation == 10, GameState.reputation)

	# Lejos del equipo o en otro equipo no cuenta.
	var ticket := TicketManager.next_for("ana")
	check("ticket de dos golpes", ticket.id == "correo" and ticket.repairs == 2, ticket.id)
	TicketManager.accept(ticket)
	player.global_position = Vector2(100, 230)
	await tick(6)
	await strike()
	check("sin equipo cerca no cuenta", TicketManager.repairs_done == 0)
	await go_to(room.get_node("Entities/Terminal_impresora"))
	await strike()
	check("equipo equivocado no cuenta", TicketManager.repairs_done == 0, dialog.text)

	# Varios golpes, con la herramienta que pide el servidor.
	await press("slot_3")
	await go_to(room.get_node("Entities/Terminal_servidor"))
	await strike()
	check("primer golpe", TicketManager.active != null and TicketManager.repairs_done == 1, dialog.text)
	var label: Label = room.get_node("HUD").get_node("%TicketLabel")
	await tick(2)
	check("progreso en HUD", label.text.contains("1/2"), label.text)
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path("res://.godot/repair_shot.png"))
	await strike()
	check("segundo golpe resuelve", TicketManager.active == null and GameState.reputation == 30, GameState.reputation)
	print("fallos: ", fails)
	get_tree().quit(1 if fails > 0 else 0)
