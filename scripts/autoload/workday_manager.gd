extends Node
## Jornadas laborales de 09:00 a 18:00: reloj, cuota, ritmo de tickets y paso de día.

signal day_ended(summary: Dictionary)
signal night_started

const CONFIG_PATH := "res://data/workdays.json"

const START_MINUTE := 9 * 60
const DAY_MINUTES := 9 * 60
const CLOCK_STEP := 5

## Las pruebas lo desactivan para que no corra el reloj.
var enabled := true
var running := false
var clock := 0.0
var day := 1
var closed_today := 0
var reputation_pace := 1.0
## Mensaje para el jugador al empezar la jornada siguiente.
var morning_note := ""
var lunch_taken := false
var _lunch_announced := false
var _config := {}
var _reputation_at_start := 0.0
var _warned_this_week := false
## Lo que faltó para pagar los gastos de anoche.
var debt := 0


func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if parsed is Dictionary:
		_config = parsed
		reputation_pace = float(_config["reputation_pace"])
	else:
		push_error("%s no es válido" % CONFIG_PATH)
	TicketManager.ticket_solved.connect(_on_ticket_solved)
	GameState.warned.connect(func() -> void: _warned_this_week = true)


func _process(delta: float) -> void:
	if not running:
		return
	clock += delta
	if in_lunch() and not _lunch_announced:
		_lunch_announced = true
		GameState.notice.emit("Hora del almuerzo: la cola se detiene. Ve a la cafetería o charla con alguien.")
	if clock >= float(_config["day_seconds"]):
		_end_day()


## Pone en marcha el reloj y la cola al entrar en la oficina.
func start_day() -> void:
	if not enabled or running:
		return
	running = true
	clock = 0.0
	lunch_taken = false
	_lunch_announced = false
	DayEvents.start_day()
	Incidents.start_day()
	DayStats.reset()
	TicketQueue.start_day()


## Pausa del almuerzo: no llegan tickets ni corren los plazos.
func in_lunch() -> bool:
	return running and day_progress() >= float(_config["lunch_start"]) and day_progress() < float(_config["lunch_end"])


## Avance de la jornada de 0 a 1.
func day_progress() -> float:
	return clampf(clock / float(_config["day_seconds"]), 0.0, 1.0)


func salary() -> int:
	return int(_chapter().get("salary", 0))


func week() -> int:
	return (day - 1) / int(_config["days_per_week"])


func quota() -> int:
	var relief := CareerProfile.quota_relief() if week() == 0 else 0
	var themed := roundi(DayEvents.mod("quota", 0.0))
	return maxi(1, mini(int(_config["base_quota"]) + week() * int(_config["quota_per_week"]), int(_config["max_quota"])) - relief + themed)


## Segundos entre tickets: cada semana llegan más seguidos.
func spawn_interval() -> float:
	var base := maxf(float(_config["ticket_interval"]) - week() * float(_config["interval_step"]), float(_config["min_interval"]))
	return base * DayEvents.mod("interval", 1.0)


func max_pending() -> int:
	return int(_config["max_pending"])


## Estrés por segundo que suma cada ticket en espera.
func queue_stress() -> float:
	return difficulty("queue_stress")


## Valor de la curva de dificultad para la semana actual; tras la última, se mantiene.
func difficulty(key: String) -> float:
	var weeks: Array = _config["weeks"]
	return float(weeks[mini(week(), weeks.size() - 1)][key])


## Gastos de vida del día según el puesto, menos lo que ahorren las mejoras.
func expenses() -> int:
	return maxi(0, int(_chapter().get("expenses", 0)) - Upgrades.expense_saving())


func event_pace() -> float:
	return float(_config["event_pace"])


func clock_text() -> String:
	var minutes := int(clock / float(_config["day_seconds"]) * DAY_MINUTES / CLOCK_STEP) * CLOCK_STEP + START_MINUTE
	return "%02d:%02d" % [minutes / 60, minutes % 60]


func label() -> String:
	var per_week := int(_config["days_per_week"])
	return "Semana %d, día %d" % [(day - 1) / per_week + 1, (day - 1) % per_week + 1]


func short_label() -> String:
	var per_week := int(_config["days_per_week"])
	return "S%d D%d" % [(day - 1) / per_week + 1, (day - 1) % per_week + 1]


func chapter_brief() -> String:
	return _chapter().get("brief", "")


## Fase de la carrera, como "Semana de Practicante".
func phase() -> String:
	return _chapter().get("phase", "")


func next_day() -> void:
	day += 1
	closed_today = 0
	clock = 0.0
	_reputation_at_start = GameState.reputation
	var rest_bonus := Friends.rest_bonus()
	GameState.add_stress(-float(_config["overnight_rest"]) - rest_bonus)
	ToolBelt.add_coffee(int(_config["daily_coffee"]) + Upgrades.daily_coffee())
	if debt > 0:
		GameState.add_stress(float(_config["debt_stress"]))
	morning_note = "La soledad pesa: llevas días sin hablar con nadie." if Friends.is_lonely() else ""
	if debt > 0:
		morning_note += " No llegaste a pagar los gastos: debes $%d y te quita el sueño." % debt
	if (day - 1) % int(_config["days_per_week"]) == 0:
		if not _warned_this_week and GameState.warnings > 0:
			GameState.remove_warning()
			morning_note = "Semana limpia: RR. HH. retira una amonestación."
		_warned_this_week = false


## Reinicia todos los sistemas para una partida nueva.
func new_game() -> void:
	GameState.reset()
	TicketManager.reset()
	ToolBelt.reset()
	DialogueManager.reset()
	EventDirector.reset()
	TicketQueue.reset()
	Upgrades.reset()
	StoryDirector.reset()
	DayEvents.reset()
	Overheard.reset()
	Incidents.reset()
	debt = 0
	running = false
	clock = 0.0
	day = 1
	closed_today = 0
	morning_note = ""
	_reputation_at_start = GameState.reputation
	_warned_this_week = false


func _chapter() -> Dictionary:
	for chapter: Dictionary in _config["chapters"]:
		if chapter["stage"] == GameState.stage_title():
			return chapter
	return {}


func _on_ticket_solved() -> void:
	if not enabled:
		return
	closed_today += 1
	if closed_today == quota():
		GameState.notice.emit("Cuota cumplida. Cada ticket extra suma reputación.")


func _end_day() -> void:
	running = false
	TicketManager.end_day()
	TicketQueue.reset()
	if closed_today < quota():
		GameState.add_warning("cerraste %d de %d tickets de la jornada" % [closed_today, quota()])
	if GameState.warnings >= GameState.MAX_WARNINGS:
		return
	var extra := maxi(closed_today - quota(), 0) * int(_config["extra_ticket_pay"])
	var costs := expenses()
	var balance := GameState.money + salary() + extra - costs
	debt = maxi(-balance, 0)
	GameState.add_money(salary() + extra - costs)
	day_ended.emit({
		"social": Friends.social_today,
		"grade": DayStats.grade(quota()),
		"lost": DayStats.lost,
		"average": DayStats.average_seconds(),
		"accuracy": DayStats.accuracy(),
		"tool_errors": DayStats.tool_errors,
		"stress_peak": DayStats.stress_peak,
		"salary": salary(),
		"extra": extra,
		"expenses": costs,
		"debt": debt,
		"money": GameState.money,
		"label": label(),
		"phase": phase(),
		"tickets": closed_today,
		"quota": quota(),
		"stress": GameState.stress,
		"gain": GameState.reputation - _reputation_at_start,
		"reputation": GameState.reputation,
		"warning": GameState.warning_name(),
		"title": GameState.stage_label(),
		"employee": CareerProfile.player_name,
		"brief": StoryDirector.ending_text() if GameState.reputation >= GameState.MAX_REPUTATION and not StoryDirector.ending_text().is_empty() else chapter_brief(),
		"finished": GameState.reputation >= GameState.MAX_REPUTATION,
	})
