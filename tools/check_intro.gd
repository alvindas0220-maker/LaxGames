extends Node
## Comprueba el flujo de inicio, las herramientas y captura la cinemática.
##
## Uso:  godot --path . res://tools/check_intro.tscn

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


func key(code: int) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = code
		e.pressed = down
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		await get_tree().physics_frame
		await frames(2)


func shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path(path))


func _ready() -> void:
	WorkdayManager.enabled = false
	EventDirector.enabled = false
	WorkdayManager.reputation_pace = 1.0
	check("escena principal", ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/ui/intro_cutscene.tscn")
	await get_tree().process_frame
	var intro: Node = (load("res://scenes/ui/intro_cutscene.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(intro)
	get_tree().current_scene = intro
	await frames(30)
	var story: Label = intro.get_node("%StoryLabel")
	var typed := story.visible_characters
	check("escribe letra a letra", typed > 0 and typed < story.text.length(), "%d/%d" % [typed, story.text.length()])
	check("sonido de oficina", intro.get_node("Sfx").playing and intro.get_node("Ambience").playing)
	await send("ui_accept")
	check("completa la linea", story.visible_characters >= story.text.length())
	await send("ui_accept")
	await send("ui_accept")
	await send("ui_accept")
	await frames(70)
	await shot("res://.godot/intro_line.png")
	while not intro.get_node("Alert").visible:
		await send("ui_accept")
		await send("ui_accept")
	await frames(60)
	check("alerta del servidor", intro.get_node("Alert").visible, story.text)
	await shot("res://.godot/intro_alert.png")
	var guard := 0
	while is_instance_valid(intro) and get_tree().current_scene == intro and guard < 20:
		await send("ui_accept")
		await frames(4)
		guard += 1
	await frames(12)
	var office := get_tree().current_scene
	check("carga la oficina", office != null and office.name == "Office", office)
	check("jugador listo", office.get_node_or_null("Entities/Player") != null and TicketManager.active == null and GameState.warnings == 0)
	var dialog: Label = office.get_node("HUD").get_node("%DialogLabel")
	check("aviso del primer ticket", dialog.text.contains("Ana"), dialog.text)
	await frames(4)
	await shot("res://.godot/office_start.png")

	# Herramientas.
	var slots: QuickSlots = office.get_node("HUD/Root/QuickSlots")
	check("tres ranuras", slots.get_node("Slots").get_child_count() == 3)
	await key(KEY_SPACE)
	await frames(30)
	await key(KEY_2)
	check("ranura de cafe", ToolBelt.selected == ToolBelt.Tool.COFFEE and slots.selected == 1)
	await key(KEY_SPACE)
	check("cafe sin amonestaciones", ToolBelt.coffee == 3)
	GameState.add_warning("prueba")
	await frames(30)
	await key(KEY_SPACE)
	check("cafe retira amonestacion", GameState.warnings == 0 and ToolBelt.coffee == 2, ToolBelt.coffee)
	var count: Label = slots.get_node("Slots").get_child(1).get_node("CountLabel")
	check("contador de cafe", count.text == "2", count.text)
	await key(KEY_3)
	await key(KEY_SPACE)
	check("usb sin ticket", dialog.text.contains("ningún ticket"), dialog.text)
	TicketManager.accept(TicketManager.next_for("ana"))
	await key(KEY_SPACE)
	check("usb localiza el equipo", dialog.text.contains("Ana"), dialog.text)
	await frames(4)
	await shot("res://.godot/tools_shot.png")
	print("fallos: ", fails)
	get_tree().quit(1 if fails > 0 else 0)
