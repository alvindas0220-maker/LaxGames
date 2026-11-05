extends Node
## Jornadas laborales: cuota diaria de tickets, resumen y paso de día.

signal day_ended(summary: Dictionary)

const CONFIG_PATH := "res://data/workdays.json"

## Las pruebas lo desactivan para no cortar la partida al cumplir la cuota.
var enabled := true
var day := 1
var closed_today := 0
var reputation_pace := 1.0
var _config := {}
var _reputation_at_start := 0


func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if parsed is Dictionary:
		_config = parsed
		reputation_pace = float(_config["reputation_pace"])
	else:
		push_error("%s no es válido" % CONFIG_PATH)
	TicketManager.ticket_closed.connect(_on_ticket_closed)


func quota() -> int:
	var week := (day - 1) / int(_config["days_per_week"])
	return mini(int(_config["base_quota"]) + week * int(_config["quota_per_week"]), int(_config["max_quota"]))


func label() -> String:
	var per_week := int(_config["days_per_week"])
	return "Semana %d, día %d" % [(day - 1) / per_week + 1, (day - 1) % per_week + 1]


func chapter_brief() -> String:
	for chapter: Dictionary in _config["chapters"]:
		if chapter["stage"] == GameState.stage_title():
			return chapter["brief"]
	return ""


func next_day() -> void:
	day += 1
	closed_today = 0
	_reputation_at_start = GameState.reputation


## Reinicia todos los sistemas para una partida nueva.
func new_game() -> void:
	GameState.reset()
	TicketManager.reset()
	ToolBelt.reset()
	DialogueManager.reset()
	EventDirector.reset()
	day = 1
	closed_today = 0
	_reputation_at_start = 0


func _on_ticket_closed() -> void:
	if not enabled:
		return
	closed_today += 1
	if closed_today >= quota():
		# Diferido: la recompensa se aplica justo después de cerrar el ticket.
		_end_day.call_deferred()


func _end_day() -> void:
	if GameState.warnings >= GameState.MAX_WARNINGS:
		return
	day_ended.emit({
		"label": label(),
		"tickets": closed_today,
		"gain": GameState.reputation - _reputation_at_start,
		"reputation": GameState.reputation,
		"warning": GameState.warning_name(),
		"title": GameState.stage_title(),
		"brief": chapter_brief(),
		"finished": GameState.reputation >= GameState.MAX_REPUTATION,
	})
