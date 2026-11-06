extends Node
## Comprueba celular, tienda, trabajos extra, informe, ambiente y avería visible.
##
## Uso:  godot --path . res://tools/check_phone.tscn

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
	await get_tree().process_frame
	await get_tree().process_frame


func press(action: String) -> void:
	await act(action, true)
	await act(action, false)


func tab_key() -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = KEY_TAB
		e.physical_keycode = KEY_TAB
		e.pressed = down
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		await get_tree().process_frame
		await get_tree().process_frame


func shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path(path))


func view(cell: Vector2i, path: String) -> void:
	player.global_position = Vector2(cell * 16)
	await tick(30)
	await shot(path)


func _ready() -> void:
	CareerProfile.use_blank_profile()
	EventDirector.enabled = false
	TicketQueue.rng.seed = 3
	await get_tree().process_frame
	room = (load("res://scenes/world/office.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(room)
	get_tree().current_scene = room
	player = room.get_node("Entities/Player")
	await tick(8)
	var phone: Phone = room.get_node("Phone")
	var hud: Node = room.get_node("HUD")
	var text: Label = phone.get_node("%ScreenText")

	# Sin panel grande.
	var chip: Control = hud.get_node("Root/StatusPanel")
	check("indicador pequeno", chip.size.y <= 16.0 and chip.size.x <= 130.0, chip.size)
	check("sin ficha fija", hud.get_node_or_null("Root/StatusPanel/Stack/Row") == null)
	check("boton de celular", hud.get_node("%PhoneButton").count == TicketQueue.pending.size(), hud.get_node("%PhoneButton").count)

	# Tab abre y bloquea al personaje; el reloj sigue.
	await tab_key()
	check("Tab abre", phone.is_open() and GameState.input_locked)
	await tick(12)
	await shot("res://.godot/phone_status.png")
	var clock := WorkdayManager.clock
	var pos := player.global_position
	await act("move_down", true)
	await tick(6)
	await act("move_down", false)
	check("el personaje no se mueve", player.global_position == pos)
	check("la jornada sigue", WorkdayManager.clock > clock, WorkdayManager.clock)
	await press("ui_right")
	check("cambia de pestana", phone.tab == 1, phone.tab)

	# Tickets por prioridad: Crítica antes que Normal, aunque llegara después.
	TicketQueue.reset()
	TicketQueue._timer = 999.0
	WorkdayManager.day = 2
	TicketQueue.add("bruno")
	TicketQueue.add("clara")
	TicketQueue.add("ivan")
	TicketQueue.add("diego")
	WorkdayManager.day = 1
	var rows := phone.sorted_tickets()
	var order := rows.map(func(r: Dictionary) -> String: return r["priority"])
	check("ordena por prioridad", order == ["Crítica", "Alta", "Normal", "Baja"], order)
	phone.refresh()
	await tick(2)
	check("lista en pantalla", text.text.begins_with("Crítica Clara"), text.text)
	await shot("res://.godot/phone_tickets.png")
	TicketQueue.reset()
	TicketQueue._timer = 999.0

	await press("ui_right")
	check("pestana trabajo", text.text.contains("Cuota"), text.text)
	check("teclas en el celular", text.text.contains("3 USB"), text.text)
	await press("ui_right")
	check("pestana tienda", text.text.contains("Saldo"), text.text)

	# Tienda.
	var shoes: Dictionary = Upgrades.catalog[0]
	await press("ui_accept")
	check("sin dinero no compra", Upgrades.level_of("zapatos") == 0)
	GameState.add_money(1000)
	await press("ui_accept")
	check("compra mejora", Upgrades.level_of("zapatos") == 1 and GameState.money == 1000 - Upgrades.catalog[0]["prices"][0], GameState.money)
	await tick(2)
	await shot("res://.godot/phone_shop.png")
	check("mas velocidad", is_equal_approx(Upgrades.speed_scale(), 1.1), Upgrades.speed_scale())
	Upgrades._levels["zapatos"] = shoes["prices"].size()
	check("tope de nivel", Upgrades.is_maxed(shoes) and not Upgrades.buy(shoes))
	Upgrades.reset()
	Upgrades._levels["meditacion"] = 1
	GameState.stress = 0.0
	GameState.add_stress(10.0)
	check("resistencia al estres", is_equal_approx(GameState.stress, 9.2), GameState.stress)
	GameState.stress = 0.0
	Upgrades.reset()
	await tab_key()
	check("Tab cierra", not phone.is_open() and not GameState.input_locked)

	# El teléfono no se abre sobre una ventana que pausa.
	get_tree().paused = true
	phone.toggle()
	check("no abre en pausa", not phone.is_open())
	get_tree().paused = false

	# Un evento u otra ventana que pausa cierra el celular y recupera el teclado.
	phone.open(0)
	get_tree().paused = true
	await get_tree().process_frame
	await get_tree().process_frame
	check("una pausa cierra el celular", not phone.is_open() and not GameState.input_locked)
	get_tree().paused = false

	# Avería visible con síntoma real.
	var terminal: Terminal = room.get_node("Entities/Terminal_build_server")
	var other: Terminal = room.get_node("Entities/Terminal_switch")
	var build: TicketData = TicketManager.next_for("lucia")
	TicketManager.accept(build)
	check("testigo en el equipo averiado", terminal.is_faulty() and not other.is_faulty())
	terminal.interact()
	await tick(2)
	var dialog: Label = hud.get_node("%DialogLabel")
	check("sintoma real", dialog.text.contains("paquete no encontrado") and dialog.text.contains("USB"), dialog.text)
	for fault: Dictionary in TicketManager.faults.values():
		if not fault.has("symptom"):
			check("sintoma de " + fault["name"], false)
	TicketManager.reset()
	await tick(2)
	check("se apaga el testigo", not terminal.is_faulty())

	# Ambiente.
	var lighting: Node = room.get_node("Lighting")
	check("reflejos de monitor", lighting.get_node("Screens").get_child_count() > 40, lighting.get_node("Screens").get_child_count())
	check("LED de servidores", lighting.get_node("Leds").get_child_count() >= 20, lighting.get_node("Leds").get_child_count())
	check("vapor en la cafetera", lighting.get_node("Steam").emitting)
	check("luz segun la hora", lighting.ambient_at(0.0) != lighting.ambient_at(1.0) and lighting.ambient_at(0.5) == Color.WHITE)
	var world: TileMapLayer = room.get_node("WorldLayer")
	var monitor := world.get_cell_atlas_coords(Vector2i(2, 2))
	check("monitor animado", world.tile_set.get_source(0).get_tile_animation_frames_count(monitor) == 2, monitor)
	var led_alpha := {}
	for i in 60:
		await tick(1)
		led_alpha[lighting.get_node("Leds").modulate.a] = true
	check("LED parpadean", led_alpha.size() >= 2, led_alpha.keys())

	# Informe de jornada.
	var summary: Array = []
	WorkdayManager.day_ended.connect(func(s: Dictionary) -> void: summary.append(s), CONNECT_ONE_SHOT)
	DayStats.reset()
	DayStats.hits = 8
	DayStats.misses = 2
	DayStats.lost = 1
	DayStats.tool_errors = 2
	DayStats.stress_peak = 40.0
	WorkdayManager.closed_today = 5
	DayStats.solved = 5
	var money := GameState.money
	WorkdayManager.clock = 9999.0
	await tick(3)
	check("metricas", summary[0]["tool_errors"] == 2 and is_equal_approx(summary[0]["accuracy"], 80.0) and summary[0]["lost"] == 1, summary[0]["grade"])
	check("calificacion", summary[0]["grade"] == "A", DayStats.score(5))
	check("cobra el sueldo", GameState.money == money + WorkdayManager.salary(), GameState.money)
	var report: Label = room.get_node("DaySummary").get_node("%SummaryLabel")
	check("informe en pantalla", report.text.contains("Calificación A") and report.text.contains("Precisión 80%") and report.text.contains("ahorros"), report.text)
	await shot("res://.godot/report.png")

	# Noche: trabajo extra con minijuego.
	await get_tree().create_timer(0.45, true, false, true).timeout
	await press("ui_accept")
	await get_tree().process_frame
	var night: NightMenu = room.get_node("NightMenu")
	check("noche", night.get_node("Panel").visible and GameState.night and night.offers.size() == 3, night.offers.size())
	await RenderingServer.frame_post_draw
	await shot("res://.godot/night.png")
	var bar: RepairBar = room.get_node("RepairBar")
	var gig: Dictionary = night.offers[0]
	var cash := GameState.money
	var stress_before := GameState.stress
	await get_tree().create_timer(0.45, true, false, true).timeout
	await press("ui_accept")
	check("abre el trabajo", bar.get_node("Panel").visible and bar._gig_left == gig["rounds"], bar._gig_left)
	await shot("res://.godot/gig.png")
	while bar._gig_left > 0:
		bar._judge(true)
		await get_tree().process_frame
	check("cobra el trabajo", GameState.money == cash + gig["pay"], GameState.money)
	check("suma estres", GameState.stress > stress_before, GameState.stress)
	check("vuelve a la noche", night.get_node("Panel").visible and night.offers.size() == 2 and night.done_tonight == 1)
	# Fallar paga menos.
	var second: Dictionary = night.offers[0]
	night._choice = 0
	night.start_gig(0)
	bar._tool = "kit"
	bar._miss()
	cash = GameState.money
	while bar._gig_left > 0:
		bar._judge(true)
		await get_tree().process_frame
	check("los fallos pagan menos", GameState.money == cash + roundi(second["pay"] * 0.85), GameState.money - cash)
	night.start_gig(0)
	check("limite por noche", not bar.get_node("Panel").visible and night.get_node("%NightResult").text.contains("horas"), night.get_node("%NightResult").text)
	# Tienda desde la noche, con el juego en pausa.
	night._choice = night.offers.size()
	night._confirm()
	await get_tree().process_frame
	check("tienda de noche", phone.is_open() and phone.tab == Phone.SHOP_TAB)
	phone.close()
	night._choice = night.offers.size() + 1
	await get_tree().create_timer(0.45, true, false, true).timeout
	await press("ui_accept")
	await tick(10)
	room = get_tree().current_scene
	check("nuevo dia", WorkdayManager.day == 2 and WorkdayManager.running and not GameState.night and not get_tree().paused, WorkdayManager.day)

	# Partida nueva sin mejoras.
	Upgrades._levels["zapatos"] = 1
	GameState.add_money(50)
	WorkdayManager.new_game()
	check("partida nueva limpia", Upgrades.level_of("zapatos") == 0 and GameState.money == 0)

	# Vistas de ambiente.
	WorkdayManager.running = false
	player = room.get_node("Entities/Player")
	for cell: Vector2i in [Vector2i(10, 7), Vector2i(34, 6), Vector2i(8, 38)]:
		await view(cell, "res://.godot/light_%d_%d.png" % [cell.x, cell.y])
	WorkdayManager.clock = 299.0
	await view(Vector2i(54, 6), "res://.godot/light_dusk.png")
	print("fallos: ", fails)
	get_tree().quit(1 if fails > 0 else 0)
