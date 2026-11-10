extends Node
## Bot de pruebas: juega solo con pulsaciones reales y escribe un informe.
##
## Durante la partida: F12 lo activa o desactiva.
## Desde consola:      godot --path . --fixed-fps 60 -- --qa-bot --qa-days=5
## Opciones: --qa-seed=N, --qa-max-seconds=N, --qa-report=RUTA, --qa-random (elige
## opciones al azar en vez de las que dan pistas), --qa-skill=0.7 (juega como una
## persona: falla y tarda más; 1 es perfecto).
## Informe por defecto en user://qa_report.txt. Solo existe en compilaciones de depuración.

const CONFIRM_GAP := 0.5
const COFFEE_AT := 70.0
const GOSSIP_EVERY := 6.0
## Puntos de reputación antes del momento de la decisión en que se pone a investigar.
const CLUE_MARGIN := 25.0
## Límites para declarar un bloqueo, en segundos de juego.
## Las ventanas esperan tiempo real, así que su límite también lo es.
const SCREEN_LIMIT := 12.0
const MINIGAME_LIMIT := 30.0
const TARGET_LIMIT := 45.0
const SLOTS := {"kit": "slot_1", "usb": "slot_3", "tester": "slot_4"}
const COFFEE_SLOT := "slot_2"
const TOOL_ID := {"slot_1": ToolBelt.Tool.KIT, "slot_2": ToolBelt.Tool.COFFEE, "slot_3": ToolBelt.Tool.USB, "slot_4": ToolBelt.Tool.TESTER}

var active := false
var log := QaLog.new()
var _headless_run := false
var _max_days := 3
var _max_seconds := 1800.0
var _random_choices := false
var _rng := RandomNumberGenerator.new()
var _walker: QaWalker
var _solver := QaSolver.new()
var _room: Node
var _player: CharacterBody2D
var _interactor: Interactor
var _confirm_wait := 0.0
var _screen := ""
var _screen_time := 0.0
var _minigame_time := 0.0
var _target: Area2D
var _target_time := 0.0
var _gossip_wait := 0.0
var _ignored := {}
var _finished := false
var _overlay: Label
var _accepted_at := 0.0
var _real_delta := 0.0
var _last_ms := 0
var _release_attack := false
## Métricas.
var _accepted := 0
var _solved := 0
var _lost := 0
var _expired := 0
var _days_done := 0
var _fired := 0
var _purchases := 0
var _incidents := 0
var _incidents_clean := 0
var _clues := 0
var _solve_times: Array[float] = []
var _kinds := {}
var _kind_started := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.is_debug_build():
		set_process(false)
		set_process_unhandled_key_input(false)
		return
	OS.add_logger(log)
	_connect_signals()
	_build_overlay()
	var args := OS.get_cmdline_user_args()
	if "--qa-bot" in args:
		_read_arguments(args)
		_headless_run = true
		CareerProfile.use_blank_profile()
		StoryDirector.enabled = true
		start()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F12:
		if active:
			stop()
		else:
			start()
		get_viewport().set_input_as_handled()


func start() -> void:
	active = true
	log.enabled = true
	_overlay.show()
	log.note("Bot activado, semilla %d" % _rng.seed)


func stop() -> void:
	active = false
	_overlay.hide()
	_release_input()
	_write_report()
	log.enabled = false


func _process(delta: float) -> void:
	if not active or _finished:
		return
	var now := Time.get_ticks_msec()
	_real_delta = (now - _last_ms) / 1000.0
	_last_ms = now
	_confirm_wait -= _real_delta
	_gossip_wait -= delta
	if _release_attack:
		_release_attack = false
		_solver.send("attack", false)
	if log.elapsed() >= _max_seconds:
		log.problem("TIEMPO", "Se alcanzó el límite de %d s" % _max_seconds)
		_finish()
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	match scene.name:
		"MainMenu":
			_watch("menu")
			if _confirm_wait <= 0.0:
				scene.select_id("nueva")
				_confirm("ui_accept")
		"NameEntry":
			_watch("alta")
			_play_name_entry(scene)
		"IntroCutscene":
			_watch("intro")
			_confirm("ui_accept")
		"Office":
			_play_office(scene, delta)
		_:
			_watch("escena " + scene.name)


func _play_name_entry(scene: Control) -> void:
	if _confirm_wait > 0.0:
		return
	if scene.get_node("Panel").visible:
		_confirm_wait = CONFIRM_GAP
		scene.submit_name("QA Bot")
	else:
		scene.row = CareerProfile.trait_catalog.size() + 1
		_confirm("ui_accept")


func _play_office(room: Node, delta: float) -> void:
	if room != _room:
		_enter_room(room)
	var bar: RepairBar = room.get_node("RepairBar")
	if bar.get_node("Panel").visible:
		_release_movement()
		_watch("minijuego")
		_track_minigame(bar, delta)
		_solver.solve(bar, delta)
		return
	if not _kind_started.is_empty():
		_close_minigame()
	_solver.reset()
	if room.get_node("GameOver/Panel").visible:
		_watch("despido")
		_confirm("ui_accept")
	elif room.get_node("DaySummary/Panel").visible:
		_watch("informe")
		_confirm("ui_accept")
	elif room.get_node("NightMenu/Panel").visible:
		_watch("noche")
		_play_night(room.get_node("NightMenu"))
	elif room.get_node("EpisodeCard/Panel").visible:
		_watch("episodio")
		_confirm("ui_accept")
	elif room.get_node("EventPanel/Panel").visible:
		_watch("dialogo")
		_answer(room.get_node("EventPanel"))
	elif get_tree().paused:
		_watch("pausa sin ventana")
	else:
		_screen = ""
		_play_world(delta)


func _enter_room(room: Node) -> void:
	_room = room
	_player = room.get_node("Entities/Player")
	_interactor = _player.get_node("Interactor")
	_walker = QaWalker.new()
	_walker.setup(room, _player)
	_walker.reset_tracking()
	_target = null
	_ignored.clear()


func _play_night(night: NightMenu) -> void:
	if _confirm_wait > 0.0:
		return
	_shop()
	if night.done_tonight == 0 and not night.offers.is_empty() and GameState.stress < 60.0:
		night._choice = 0
	else:
		night._choice = night.offers.size() + 1
	_confirm("ui_accept")


## Compra la mejora más barata que pueda pagar, guardando para los gastos de mañana.
func _shop() -> void:
	var cheapest: Dictionary = {}
	for entry: Dictionary in Upgrades.catalog:
		if not Upgrades.is_maxed(entry) and (cheapest.is_empty() or Upgrades.price_of(entry) < Upgrades.price_of(cheapest)):
			cheapest = entry
	if not cheapest.is_empty() and GameState.money - Upgrades.price_of(cheapest) >= WorkdayManager.expenses() * 2:
		var price := Upgrades.price_of(cheapest)
		if Upgrades.buy(cheapest):
			_purchases += 1
			log.note("Compra %s por $%d" % [cheapest["name"], price])


## Elige respuesta: prefiere las que dan pistas o relajan; con --qa-random, al azar.
func _answer(panel: Node) -> void:
	if _confirm_wait > 0.0:
		return
	var options: Array = panel._event["options"]
	var choice := 0
	if _random_choices:
		choice = _rng.randi_range(0, options.size() - 1)
	else:
		for i in options.size():
			if options[i].has("clue"):
				choice = i
				break
	panel._select(choice)
	_confirm("ui_accept")


func _play_world(delta: float) -> void:
	if GameState.stress >= COFFEE_AT and ToolBelt.coffee > 0 and TicketManager.active == null:
		_use_tool(COFFEE_SLOT)
		return
	var goal := _choose_target()
	if goal == null:
		_release_movement()
		return
	if goal != _target:
		_target = goal
		_target_time = 0.0
		_walker.reset_tracking()
	_target_time += delta
	if _target_time > TARGET_LIMIT:
		log.problem("OBJETIVO", "Sin alcanzar %s en %d s; jugador en %s, objetivo en %s, solapa=%s, bloqueado=%s, reparando=%s, herramienta=%d" % [goal.name, TARGET_LIMIT, _player.global_position.round(), goal.global_position.round(), goal in _interactor.get_overlapping_areas(), _player._locked, TicketManager.repairing, ToolBelt.selected])
		_ignored[goal] = true
		_target = null
		return
	if goal in _interactor.get_overlapping_areas():
		_release_movement()
		_act_on(goal)
	elif not _walker.walk_to(goal.global_position, delta) and _walker.stuck_count % 5 == 1:
		log.note("Ruta atascada hacia %s" % goal.name)


func _choose_target() -> Area2D:
	if TicketManager.active != null:
		return _terminal_of(TicketManager.current_target())
	if WorkdayManager.in_lunch() and not WorkdayManager.lunch_taken:
		return _room.get_node("Entities/LunchTable")
	if _needs_clues():
		var clue := _clue_target()
		if clue != null:
			return clue
	var best: Area2D
	var worst := -1.0
	for npc: Npc in get_tree().get_nodes_in_group("npcs"):
		if TicketQueue.pending.has(npc.npc_id) and TicketQueue.urgency(npc.npc_id) > worst and not _ignored.has(npc.get_node("Reach")):
			worst = TicketQueue.urgency(npc.npc_id)
			best = npc.get_node("Reach")
	if best != null:
		return best
	return _clue_target() if _gossip_wait <= 0.0 else null


## Cerca del tope de reputación, la trama pasa por delante de la cola.
func _needs_clues() -> bool:
	var entry := StoryDirector.current_act()
	return not entry.is_empty() and GameState.reputation >= float(entry["ready"]) - CLUE_MARGIN


func _clue_target() -> Area2D:
	for spot: Node in _room.get_node("Entities").get_children():
		if spot is ClueSpot and spot._shows_glint() and not _ignored.has(spot):
			return spot
	for npc: Npc in get_tree().get_nodes_in_group("npcs"):
		if not StoryDirector.next_gossip(npc.npc_id).is_empty() and not _ignored.has(npc.get_node("Reach")):
			return npc.get_node("Reach")
	return null


func _act_on(goal: Area2D) -> void:
	if goal is Terminal:
		_use_tool(SLOTS[TicketManager.current_tool()])
		return
	if _confirm_wait > 0.0:
		return
	_confirm_wait = 0.2
	if _interactor._target == goal:
		_solver.tap("interact")
		_gossip_wait = GOSSIP_EVERY
	else:
		log.note("Hay otro objetivo más cerca que %s: se interactúa directamente" % goal.get_parent().name)
		goal.interact()
		_gossip_wait = GOSSIP_EVERY


func _use_tool(slot: String) -> void:
	if ToolBelt.selected != TOOL_ID[slot]:
		_solver.tap(slot)
		return
	if _player._locked or _confirm_wait > 0.0:
		return
	_confirm_wait = 0.25
	_solver.send("attack", true)
	_release_attack = true


func _terminal_of(target_id: String) -> Area2D:
	for terminal: Terminal in get_tree().get_nodes_in_group("terminals"):
		if terminal.target_id == target_id:
			return terminal
	log.problem("DATOS", "No hay equipo para %s" % target_id)
	return null


func _confirm(action: String) -> void:
	if _confirm_wait > 0.0:
		return
	_confirm_wait = CONFIRM_GAP
	_solver.send(action, true)
	_solver.send(action, false)


## Vigila que una misma pantalla no se quede abierta para siempre.
func _watch(screen: String) -> void:
	if screen != _screen:
		_screen = screen
		_screen_time = 0.0
	_screen_time += _real_delta
	if _screen_time > SCREEN_LIMIT:
		log.problem("PANTALLA", "Atascado en '%s'" % screen)
		_screen_time = 0.0


func _track_minigame(bar: RepairBar, delta: float) -> void:
	if _kind_started.is_empty():
		_kind_started = {"kind": bar._kind, "time": 0.0}
		_minigame_time = 0.0
	if _kind_started["kind"] != bar._kind:
		_close_minigame()
		_kind_started = {"kind": bar._kind, "time": 0.0}
	_kind_started["time"] += delta
	_minigame_time += delta
	if _minigame_time > MINIGAME_LIMIT:
		log.problem("MINIJUEGO", "Sin terminar '%s'" % bar._kind)
		_minigame_time = 0.0
		_solver.tap("ui_cancel")


func _close_minigame() -> void:
	var kind: String = _kind_started["kind"]
	var entry: Dictionary = _kinds.get(kind, {"count": 0, "time": 0.0})
	entry["count"] += 1
	entry["time"] += _kind_started["time"]
	_kinds[kind] = entry
	_kind_started = {}


func _connect_signals() -> void:
	TicketManager.ticket_accepted.connect(_on_accepted)
	TicketManager.ticket_solved.connect(_on_solved)
	TicketManager.ticket_lost.connect(func() -> void:
		_lost += 1
		log.note("Ticket perdido por plazo"))
	TicketQueue.ticket_expired.connect(func() -> void:
		_expired += 1
		log.note("Ticket caducado en cola"))
	WorkdayManager.day_ended.connect(_on_day_ended)
	GameState.fired.connect(_on_fired)
	Incidents.started.connect(func(ids: Array) -> void:
		_incidents += 1
		log.note("Incidente crítico con %d averías" % ids.size()))
	Incidents.resolved.connect(func(clean: bool) -> void:
		_incidents_clean += 1 if clean else 0
		log.note("Incidente cerrado %s" % ("limpio" if clean else "con pérdidas")))
	StoryDirector.clue_found.connect(func(id: String) -> void:
		_clues += 1
		log.note("Pista: %s" % id))


func _on_accepted(ticket: TicketData) -> void:
	_accepted += 1
	_accepted_at = log.elapsed()
	log.note("Acepta %s (%s, %s)" % [ticket.id, ticket.fault, ticket.tool])


func _on_solved() -> void:
	_solved += 1
	_solve_times.append(TicketManager.last_solve_seconds)
	log.note("Resuelto en %.1f s" % TicketManager.last_solve_seconds)


func _on_day_ended(summary: Dictionary) -> void:
	if not active:
		return
	_days_done += 1
	log.note("Jornada %d: nota %s, %d/%d tickets, perdidos %d, precisión %d%%, estrés %d%% (pico %d%%), reputación %.1f%%, $%d" % [
		_days_done, summary["grade"], summary["tickets"], summary["quota"], summary["lost"], summary["accuracy"], summary["stress"], summary["stress_peak"], summary["reputation"], summary["money"],
	] + (", deuda $%d" % summary["debt"] if summary["debt"] > 0 else ""))
	if _days_done >= _max_days:
		_finish.call_deferred()


func _on_fired() -> void:
	if not active:
		return
	_fired += 1
	var kind := "sin responsabilidad" if GameState.fired_for_cause else "con responsabilidad"
	log.problem("DESPIDO", "%s en la jornada %d" % [kind, WorkdayManager.day])


func _finish() -> void:
	_finished = true
	_release_input()
	_write_report()
	if _headless_run:
		get_tree().quit(1 if not log.errors.is_empty() or _has_blockers() else 0)


func _has_blockers() -> bool:
	return log.problems.any(func(text: String) -> bool: return not text.begins_with("DESPIDO"))


func _write_report() -> void:
	var average := 0.0
	for seconds in _solve_times:
		average += seconds
	average /= maxi(_solve_times.size(), 1)
	var lines := PackedStringArray([
		"Fecha: %s" % Time.get_datetime_string_from_system(),
		"Tiempo real: %.1f s" % log.elapsed(),
		"Jornadas: %d de %d, último día %d" % [_days_done, _max_days, WorkdayManager.day],
		"Tickets: aceptados %d, resueltos %d, perdidos %d, caducados %d" % [_accepted, _solved, _lost, _expired],
		"Tiempo medio por ticket: %.1f s" % average,
		"Despidos: %d" % _fired,
		"Habilidad del bot: %.2f" % _solver.skill,
		"Incidentes: %d, sin pérdidas %d" % [_incidents, _incidents_clean],
		"Compras: %d, dinero final $%d" % [_purchases, GameState.money],
		"Pistas: %d, acto %d" % [_clues, StoryDirector.act],
		"Reputación: %.1f%%, puesto: %s" % [GameState.reputation, GameState.stage_title()],
		"Atascos de ruta: %d" % (_walker.stuck_count if _walker != null else 0),
		"Minijuegos:",
	])
	for kind: String in _kinds:
		lines.append("  %s: %d veces, media %.1f s" % [kind, _kinds[kind]["count"], float(_kinds[kind]["time"]) / int(_kinds[kind]["count"])])
	log.write(lines)


func _release_movement() -> void:
	if _walker != null:
		_walker.stop()


func _release_input() -> void:
	_release_movement()
	_solver.reset()


func _read_arguments(args: PackedStringArray) -> void:
	_rng.seed = 1
	for arg: String in args:
		if arg.begins_with("--qa-days="):
			_max_days = arg.get_slice("=", 1).to_int()
		elif arg.begins_with("--qa-seed="):
			_rng.seed = arg.get_slice("=", 1).to_int()
		elif arg.begins_with("--qa-max-seconds="):
			_max_seconds = arg.get_slice("=", 1).to_float()
		elif arg.begins_with("--qa-report="):
			log.path = arg.get_slice("=", 1)
		elif arg.begins_with("--qa-skill="):
			_solver.skill = clampf(arg.get_slice("=", 1).to_float(), 0.3, 1.0)
		elif arg == "--qa-random":
			_random_choices = true
	seed(_rng.seed)


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_overlay = Label.new()
	_overlay.text = "QA BOT"
	_overlay.position = Vector2(170, 2)
	_overlay.add_theme_font_override("font", load("res://assets/fonts/hud_pixel.fnt"))
	_overlay.add_theme_font_size_override("font_size", 8)
	_overlay.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
	_overlay.hide()
	layer.add_child(_overlay)
