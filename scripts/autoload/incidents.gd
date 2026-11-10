extends Node
## Incidentes críticos: varias averías a la vez, con alarma, más estrés en cola,
## menos paciencia y mejor premio. Su probabilidad crece con las semanas.

signal started(npc_ids: Array)
signal resolved(clean: bool)

const MIN_AT := 0.15
const MAX_AT := 0.75
const SIZE_MIN := 2
const SIZE_MAX := 3
const REWARD_SCALE := 1.5
const WAIT_SCALE := 0.75
## Cuánto estresa cada ticket crítico en espera respecto a uno normal.
const QUEUE_STRESS_SCALE := 2.0
const MISSED_STRESS := 10.0
const CLEAN_BONUS_REPUTATION := 2.0
const CLEAN_BONUS_MONEY := 40

var rng := RandomNumberGenerator.new()
## npc_id de cada ticket crítico aún abierto.
var critical := {}
var _start_at := -1.0
var _missed := false


func _ready() -> void:
	rng.randomize()
	TicketManager.ticket_solved.connect(_on_closed.bind(false))
	TicketManager.ticket_lost.connect(_on_closed.bind(true))
	TicketQueue.ticket_expired.connect(_on_expired)


func _process(_delta: float) -> void:
	if _start_at < 0.0 or not WorkdayManager.running or WorkdayManager.in_lunch() or get_tree().paused:
		return
	if WorkdayManager.day_progress() >= _start_at:
		_start_at = -1.0
		trigger()


## Decide al empezar el día si habrá incidente y a qué hora.
func start_day() -> void:
	critical.clear()
	_missed = false
	_start_at = -1.0
	if StoryDirector.enabled and rng.randf() < WorkdayManager.difficulty("incident_chance"):
		_start_at = rng.randf_range(MIN_AT, MAX_AT)


func trigger() -> bool:
	var busy := TicketManager.active.requester_id if TicketManager.active != null else ""
	var free: Array = NpcDatabase.ids().filter(func(id: String) -> bool:
		return id != busy and not TicketQueue.pending.has(id) and StoryDirector.is_present(id) and TicketManager.next_for(id) != null)
	free.shuffle()
	var chosen: Array = []
	for npc_id: String in free.slice(0, rng.randi_range(SIZE_MIN, SIZE_MAX)):
		critical[npc_id] = true
		if TicketQueue.add(npc_id):
			chosen.append(npc_id)
	if chosen.is_empty():
		critical.clear()
		return false
	AudioDirector.play("alarm")
	GameState.notice.emit("¡INCIDENTE CRÍTICO! %d averías a la vez. Atiéndelas antes que nada." % chosen.size())
	started.emit(chosen)
	return true


func is_critical(npc_id: String) -> bool:
	return critical.has(npc_id)


func reward_scale(npc_id: String) -> float:
	return REWARD_SCALE if is_critical(npc_id) else 1.0


func wait_scale(npc_id: String) -> float:
	return WAIT_SCALE if is_critical(npc_id) else 1.0


func queue_stress_scale(npc_id: String) -> float:
	return QUEUE_STRESS_SCALE if is_critical(npc_id) else 1.0


func reset() -> void:
	critical.clear()
	_start_at = -1.0
	_missed = false


func _on_closed(failed: bool) -> void:
	var npc_id := TicketManager.last_requester
	if not critical.has(npc_id):
		return
	_missed = _missed or failed
	if failed:
		GameState.add_stress(MISSED_STRESS)
	_close(npc_id)


func _on_expired() -> void:
	var npc_id := TicketQueue.last_expired
	if critical.has(npc_id):
		_missed = true
		GameState.add_stress(MISSED_STRESS)
		_close(npc_id)


func _close(npc_id: String) -> void:
	critical.erase(npc_id)
	if not critical.is_empty():
		return
	if _missed:
		GameState.notice.emit("Incidente cerrado, pero con daños. Gerencia lo apunta.")
	else:
		GameState.add_reputation(CLEAN_BONUS_REPUTATION)
		GameState.add_money(CLEAN_BONUS_MONEY)
		GameState.notice.emit("Incidente resuelto sin pérdidas: +%d%% y $%d de prima." % [CLEAN_BONUS_REPUTATION, CLEAN_BONUS_MONEY])
	resolved.emit(not _missed)
