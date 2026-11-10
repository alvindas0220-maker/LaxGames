extends Node
## Comprueba trama, chismes, grupos y los minijuegos de los equipos nuevos.
##
## Uso:  godot --path . res://tools/check_story.tscn

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


func event_for(action: String) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	return e


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

	# Coherencia de los datos.
	var catalog: Dictionary = StoryDirector.clue_catalog()
	var sources := {}
	for node: Dictionary in StoryDirector.gossip_nodes().values():
		for option: Dictionary in node["options"]:
			if option.has("clue"):
				sources[option["clue"]] = true
			if option.has("next"):
				check("siguiente valido " + node["id"], StoryDirector.gossip_nodes().has(option["next"]))
		check("orador valido " + node["id"], NpcDatabase.has_npc(node["speaker"]))
	for ticket: TicketData in TicketManager.catalog:
		if not ticket.clue.is_empty():
			sources[ticket.clue] = true
			check("pista de ticket existe " + ticket.id, catalog.has(ticket.clue))
	var room: Node = (load("res://scenes/world/office.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(room)
	get_tree().current_scene = room
	await frames(8)
	for node in room.get_node("Entities").get_children():
		if node is ClueSpot:
			sources[node.clue_id] = true
	var orphan: Array = catalog.keys().filter(func(id: String) -> bool: return not sources.has(id))
	check("toda pista se puede conseguir", orphan.is_empty(), orphan)
	check("un grupo por NPC", NpcDatabase.ids().all(func(id: String) -> bool: return Factions.NAMES.has(Factions.faction_of(id))))
	for act: int in [1, 2, 3]:
		StoryDirector.act = act
		var entry := StoryDirector.current_act()
		check("acto %d alcanzable" % act, entry["clues"].size() >= int(entry["needed"]), entry["title"])
	StoryDirector.act = 1

	# Equipos nuevos.
	var targets := {}
	for node in room.get_node("Entities").get_children():
		if node is Terminal:
			targets[node.target_id] = node
	for id: String in ["rack_raid", "biometrico", "laptop_ejecutiva", "hvac", "camara", "estacion_trabajo"]:
		check("equipo " + id, targets.has(id) and ToolBelt.TARGET_PLACES.has(id))

	# Tope de carrera según la trama.
	StoryDirector.enabled = true
	GameState.reputation = 90.0
	GameState.add_reputation(50.0)
	check("sin resolver no llega al 100", GameState.reputation < 100.0 and GameState.stage_title() != "Jefe de IT", GameState.reputation)

	# Chisme ramificado y efecto en los grupos.
	var panel: Control = room.get_node("EventPanel/Panel")
	var ivan: Npc = room.get_node("Entities/Npc_ivan")
	WorkdayManager.day = 3
	var node: Dictionary = StoryDirector.next_gossip("ivan")
	check("chisme disponible", node.get("id") == "ivan_licencias", node.get("id"))
	WorkdayManager.running = true
	TicketQueue.pending.clear()
	ivan.interact()
	await frames(3)
	check("abre el dialogo", panel.visible and get_tree().paused)
	await shot("res://.godot/story_gossip.png")
	await get_tree().create_timer(0.45, true, false, true).timeout
	await press("ui_accept")
	await frames(2)
	check("rama: sigue la conversacion", panel.visible and room.get_node("EventPanel").get_node("%EventText").text.contains("licencias"))
	check("elegir bando cambia los grupos", Factions.value_of("tecnicos") == 10 and Factions.value_of("desarrollo") == -8, Factions.standing)
	await get_tree().create_timer(0.45, true, false, true).timeout
	await press("ui_accept")
	await frames(2)
	check("pista por chisme", StoryDirector.has_clue("licencias_ivan") and not panel.visible and not get_tree().paused)
	check("un chisme por dia", StoryDirector.next_gossip("ivan").is_empty())
	WorkdayManager.running = false

	# Trato según el grupo.
	check("neutral sin cambios", is_equal_approx(Factions.reward_scale("ana"), 1.0))
	Factions.change({"administracion": 20, "desarrollo": -20})
	check("amigos pagan mejor", Factions.reward_scale("ana") > 1.0 and Factions.wait_scale("ana") > 1.0)
	check("enemigos esperan menos", Factions.reward_scale("lucia") < 1.0 and Factions.wait_scale("lucia") < 1.0)
	check("saludo distinto", Factions.greeting("ana") != "" and Factions.greeting("ana") != Factions.greeting("lucia"))
	check("bloquea chismes por trato", not StoryDirector.is_available({"faction_min": {"desarrollo": 0}}))

	# Evento que depende de una decisión previa.
	check("evento oculto", not StoryDirector.is_available({"flags": ["traidor_infra"]}))
	StoryDirector.set_flag("traidor_infra")
	check("evento tras la decision", StoryDirector.is_available({"flags": ["traidor_infra"]}))

	# Secreto escondido.
	var future: ClueSpot = room.get_node("Entities/Clue_disco_ducto")
	future.interact()
	check("pista futura no aparece antes", not StoryDirector.has_clue("disco_ducto") and not StoryDirector.can_find("disco_ducto"))
	var spot: ClueSpot = room.get_node("Entities/Clue_factura_nexo")
	spot.interact()
	check("secreto hallado", StoryDirector.has_clue("factura_nexo"))
	check("pista en el celular", "\n".join(StoryDirector.case_lines()).contains("Factura de Nexo"))
	var phone: Phone = room.get_node("Phone")
	phone.open(Phone.CASE_TAB)
	await frames(2)
	await shot("res://.godot/story_case.png")
	phone.close()

	# Con todas las pistas, la decisión espera a que la carrera llegue a ese punto.
	GameState.reputation = 40.0
	for id: String in ["pagos_ana", "cunado_bruno", "archivo_rrhh"]:
		StoryDirector.discover(id)
	await frames(4)
	check("la decision espera a la carrera", not panel.visible and StoryDirector.act == 1, GameState.reputation)
	GameState.add_reputation(59.9)
	await frames(4)
	await skip_scene()
	check("decision del acto", panel.visible and room.get_node("EventPanel")._event["id"] == "decision_acto1", panel.visible)
	await shot("res://.godot/story_decision.png")
	await get_tree().create_timer(0.45, true, false, true).timeout
	await press("ui_accept")
	await frames(2)
	check("pasa al acto 2", StoryDirector.act == 2 and StoryDirector.flags.has("confia_sofia") and not get_tree().paused, StoryDirector.act)
	await frames(6)
	check("la decision no se repite", not panel.visible and StoryDirector.act == 2 and not get_tree().paused)
	GameState.add_reputation(5.0)
	check("ya llega al 100", GameState.stage_title() == "Jefe de IT", GameState.reputation)
	GameState.add_reputation(40.0)
	check("frena antes del 110", GameState.reputation < 110.0, GameState.reputation)

	# Reparar un equipo da una pista.
	var raid_ticket: TicketData = TicketManager.catalog.filter(func(t: TicketData) -> bool: return t.id == "raid_contabilidad")[0]
	TicketManager.accept(raid_ticket)
	TicketManager.resolve("rack_raid")
	check("pista al reparar", StoryDirector.has_clue("raid_borrado"))
	await frames(3)

	# Actos 2 y 3 hasta el final.
	for id: String in ["script_lucia", "ruido_tomas", "laptop_hugo"]:
		StoryDirector.discover(id)
	await frames(4)
	await skip_scene()
	EventDirector.choose(room.get_node("EventPanel")._event, 0)
	room.get_node("EventPanel/Panel").hide()
	get_tree().paused = false
	check("ruta honesta", StoryDirector.act == 3 and StoryDirector.flags.has("ruta_honesta"))
	GameState.add_reputation(200.0)
	check("frena antes del 200", GameState.reputation < 200.0 and GameState.stage_title() == "Ingeniero en Gran Tecnológica", GameState.reputation)
	for id: String in ["disco_ducto", "huella_fantasma", "oferta_ines", "cafe_carla"]:
		StoryDirector.discover(id)
	await frames(4)
	await skip_scene()
	EventDirector.choose(room.get_node("EventPanel")._event, 0)
	room.get_node("EventPanel/Panel").hide()
	get_tree().paused = false
	GameState.add_reputation(200.0)
	check("final abierto", GameState.reputation == 200.0 and StoryDirector.ending == "propio" and StoryDirector.ending_text() != "", GameState.reputation)
	StoryDirector.enabled = false

	# Minijuegos únicos.
	var results: Array = []
	var collect := func(ok: bool) -> void: results.append(ok)

	var raid := RaidAction.new()
	raid.finished.connect(collect)
	raid.begin(2, 1.0)
	var bay: int = 0
	while bay in raid.failed:
		bay += 1
	raid.cursor = bay
	raid.handle(event_for("attack"))
	check("disco sano no se cambia", results == [false], results)
	results.clear()
	for target: int in raid.failed.duplicate():
		raid.cursor = target
		raid.handle(event_for("attack"))
	check("cambia los dos discos", results == [true], results)

	results.clear()
	var finger := FingerprintAction.new()
	finger.finished.connect(collect)
	finger.begin(null, 1.0)
	for cell: Vector2i in finger.template:
		finger.cursor = cell
		finger.handle(event_for("attack"))
	check("huella calibrada", results == [true] and finger.template.size() == FingerprintAction.MARKS, results)

	results.clear()
	var cipher := CipherAction.new()
	cipher.finished.connect(collect)
	cipher.begin("boveda", 1.0)
	check("texto cifrado", cipher.encoded != "boveda" and cipher.encoded.length() == 6, cipher.encoded)
	for character in "boveda":
		var key := InputEventKey.new()
		key.pressed = true
		key.unicode = character.unicode_at(0)
		cipher.handle(key)
	check("contrasena descifrada", results == [true], results)

	results.clear()
	var thermo := ThermostatAction.new()
	thermo.finished.connect(collect)
	thermo.begin(null, 1.0)
	for i in 200:
		if thermo.temperature > 0.55:
			thermo.handle(event_for("move_left"))
		elif thermo.temperature < 0.47:
			thermo.handle(event_for("move_right"))
		thermo.tick(1.0 / 60.0)
		if not results.is_empty():
			break
	check("temperatura estable", results == [true], results)

	results.clear()
	var camera := CameraAction.new()
	camera.finished.connect(collect)
	camera.begin(null, 1.0)
	camera.handle(event_for("attack"))
	check("mal encuadre falla", results == [false], camera.aim)
	results.clear()
	camera.aim = camera.mark
	camera.handle(event_for("attack"))
	check("encuadre correcto", results == [true], results)

	results.clear()
	var beep := BeepAction.new()
	beep.finished.connect(collect)
	beep.begin(4, 1.0)
	check("mientras muestra ignora teclas", not beep.handle(event_for("move_up")))
	for i in 180:
		beep.tick(1.0 / 60.0)
	check("termina de mostrar", not beep.showing)
	for code: int in beep.code:
		beep.handle(event_for(BeepAction.ACTIONS[code]))
	check("codigo repetido", results == [true], results)

	# Paneles reales de cada equipo.
	var bar: RepairBar = room.get_node("RepairBar")
	for pair: Array in [["raid_contabilidad", "rack_raid", ToolBelt.Tool.KIT], ["lector_entrada", "biometrico", ToolBelt.Tool.USB], ["laptop_hugo", "laptop_ejecutiva", ToolBelt.Tool.USB], ["camara_sur", "camara", ToolBelt.Tool.TESTER], ["estacion_render", "estacion_trabajo", ToolBelt.Tool.KIT]]:
		var ticket: TicketData = TicketManager.catalog.filter(func(t: TicketData) -> bool: return t.id == pair[0])[0]
		TicketManager.accept(ticket)
		ToolBelt.selected = pair[2]
		targets[pair[1]].repair()
		await frames(3)
		check("abre " + pair[0], bar.get_node("Panel").visible and bar._action != null, bar._kind)
		await shot("res://.godot/game_%s.png" % bar._kind)
		bar._close()
		await frames(14)
		TicketManager.reset()
	WorkdayManager.day = 1
	print("fallos: ", fails)
	get_tree().quit(1 if fails > 0 else 0)


## Pasa la escena que precede a cada decisión de la trama.
func skip_scene() -> void:
	var stage: StoryScene = get_tree().current_scene.get_node("StoryScene")
	check("escena antes de decidir", stage.is_playing())
	while stage.is_playing():
		stage._text.visible_characters = stage._text.text.length()
		stage._next()
	await frames(3)

