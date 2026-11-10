extends Node
## Comprueba guardado nocturno, carga, menú principal, pausa y opciones.
##
## Uso:  godot --path . res://tools/check_save.tscn
## Usa una ruta de pruebas: no toca la partida ni las opciones del jugador.

const TEST_SAVE := "user://partida_prueba.json"

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


func open(scene_path: String) -> Node:
	var scene: Node = (load(scene_path) as PackedScene).instantiate()
	if get_tree().current_scene != null and get_tree().current_scene != self:
		get_tree().current_scene.queue_free()
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await frames(6)
	return scene


func _ready() -> void:
	CareerProfile.use_blank_profile()
	StoryDirector.enabled = true
	EventDirector.enabled = false
	await get_tree().process_frame
	check("ruta de la partida", SaveGame.DEFAULT_PATH == "user://partida.json")
	SaveGame.path = TEST_SAVE
	SaveGame.persist = true
	SaveGame.delete()

	# Menú sin partida guardada.
	var menu: Control = await open("res://scenes/ui/main_menu.tscn")
	check("menu sin continuar", menu.items[0] == "nueva", menu.items)
	await shot("res://.godot/save_menu.png")

	# Partida con estado reconocible.
	var room: Node = await open("res://scenes/world/office.tscn")
	room.get_node("EpisodeCard/Panel").hide()
	get_tree().paused = false
	WorkdayManager.day = 4
	GameState.reputation = 37.5
	GameState.money = 420
	GameState.stress = 22.0
	GameState.warnings = 1
	Upgrades._levels["zapatos"] = 2
	StoryDirector.act = 2
	StoryDirector.clues["factura_nexo"] = true
	StoryDirector.set_flag("confia_sofia")
	Factions.change({"tecnicos": 14})
	Friends.change("ana", 33)
	ToolBelt.coffee = 5
	TicketManager.mark_served("ana")
	Overheard._seen["oye_banos_hugo"] = true
	var night: NightMenu = room.get_node("NightMenu")
	night.open()
	night.sleep()
	await frames(10)
	check("guarda al dormir", SaveGame.has_save())
	check("la mañana pausa con el episodio", get_tree().paused)
	var day_saved := WorkdayManager.day

	# Al volver al menú aparece Continuar y la carga restaura todo.
	WorkdayManager.new_game()
	check("partida nueva limpia la memoria", GameState.money == 0 and StoryDirector.act == 1)
	menu = await open("res://scenes/ui/main_menu.tscn")
	check("menu con continuar", menu.items[0] == "continuar" and menu.get_node("%MenuInfo").text.contains("Semana"), menu.items)
	await shot("res://.godot/save_menu_continue.png")
	await wait_guard()
	await press("ui_accept")
	await frames(10)
	check("continua en la oficina", get_tree().current_scene.name == "Office", [get_tree().current_scene.name, menu.get_node("%MenuInfo").text if is_instance_valid(menu) else "", menu.choice if is_instance_valid(menu) else -1])
	check("dia restaurado", WorkdayManager.day == day_saved, WorkdayManager.day)
	check("dinero y reputacion", GameState.money == 420 and is_equal_approx(GameState.reputation, 37.5), GameState.money)
	check("expediente", GameState.warnings == 1)
	check("mejoras", Upgrades.level_of("zapatos") == 2)
	check("trama", StoryDirector.act == 2 and StoryDirector.has_clue("factura_nexo") and StoryDirector.flags.has("confia_sofia"))
	check("grupos y amigos", Factions.value_of("tecnicos") == 14 and Friends.value_of("ana") == 33)
	check("cafe y rotacion", ToolBelt.coffee >= 5 and int(TicketManager._served.get("ana", 0)) >= 1)
	check("charlas ya oidas", Overheard._seen.has("oye_banos_hugo"))
	room = get_tree().current_scene
	room.get_node("EpisodeCard/Panel").hide()
	get_tree().paused = false
	GameState.warnings = 0

	# Pausa con Esc.
	await frames(3)
	var pause: PauseMenu = room.get_node("PauseMenu")
	await press("ui_cancel")
	check("Esc pausa", pause.is_open() and get_tree().paused)
	await shot("res://.godot/save_pause.png")
	await press("ui_cancel")
	check("Esc reanuda", not pause.is_open() and not get_tree().paused)
	room.get_node("Phone").open(0)
	await press("ui_cancel")
	check("con el celular, Esc lo cierra y no pausa", not pause.is_open() and not room.get_node("Phone").is_open())

	# Opciones desde la pausa.
	await press("ui_cancel")
	pause._select(1)
	await wait_guard()
	await press("ui_accept")
	var options: OptionsPanel = pause.get_node("%PauseOptions")
	check("abre opciones", options.visible)
	var music := Settings.music
	await press("ui_left")
	check("baja la musica", is_equal_approx(Settings.music, music - Settings.STEP), Settings.music)
	var bus := AudioServer.get_bus_index(Settings.MUSIC_BUS)
	check("aplica el volumen", is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(bus)), Settings.music))
	check("la musica va por su bus", AudioDirector._music.bus == Settings.MUSIC_BUS)
	await press("ui_down")
	await press("ui_right")
	check("efectos", is_equal_approx(Settings.sfx, 0.9))
	await shot("res://.godot/save_options.png")
	await press("ui_cancel")
	check("cierra opciones", not options.visible and pause.is_open())

	# Salir al menú pide confirmación.
	pause._select(2)
	await wait_guard()
	await press("ui_accept")
	check("pide confirmar", pause.is_open() and get_tree().current_scene.name == "Office")
	await press("ui_accept")
	await frames(10)
	check("sale al menu", get_tree().current_scene.name == "MainMenu" and not get_tree().paused)

	# Nueva partida con guardado pide confirmar y lo borra.
	menu = get_tree().current_scene
	menu.select_id("nueva")
	menu.activate("nueva")
	check("aviso de sobrescribir", SaveGame.has_save() and menu.get_node("%MenuInfo").text.contains("borrará"))
	menu.activate("nueva")
	await frames(8)
	check("borra y empieza", not SaveGame.has_save() and get_tree().current_scene.name == "NameEntry")

	# Créditos.
	menu = await open("res://scenes/ui/main_menu.tscn")
	menu.activate("creditos")
	await frames(2)
	check("creditos", menu.get_node("%Credits").visible)
	await shot("res://.godot/save_credits.png")
	await wait_guard()
	await press("ui_accept")
	check("vuelve de creditos", not menu.get_node("%Credits").visible)

	# Una partida guardada corrupta no rompe el menú.
	var file := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	file.store_string("{no es json")
	file.close()
	check("ignora partidas corruptas", not SaveGame.load_game())
	SaveGame.delete()
	SaveGame.persist = false
	SaveGame.path = SaveGame.DEFAULT_PATH
	print("fallos: ", fails)
	get_tree().quit(1 if fails > 0 else 0)
