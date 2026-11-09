extends Node
## Días temáticos: cada jornada tiene un acontecimiento que cambia su ritmo,
## con modificadores, momentos programados y tickets forzados.

signal beat_fired(beat: Dictionary)

const DATA_PATH := "res://data/daily_life.json"

## Tema de la jornada en curso; vacío si la historia está apagada.
var today := {}
var _data := {}
var _fired := {}


func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if parsed is Dictionary:
		_data = parsed
	else:
		push_error("%s no es válido" % DATA_PATH)


func _process(_delta: float) -> void:
	if today.is_empty() or not WorkdayManager.running or get_tree().paused:
		return
	var beats: Array = today.get("beats", [])
	for i in beats.size():
		if not _fired.has(i) and WorkdayManager.day_progress() >= float(beats[i]["at"]):
			if beats[i].has("event") and (TicketManager.repairing or GameState.input_locked):
				return
			_fired[i] = true
			_run(beats[i])


func data() -> Dictionary:
	return _data


## Elige el tema del día: guionizado si existe, o el de su día de la semana.
func theme_for(day: int) -> Dictionary:
	for entry: Dictionary in _data.get("themed_days", []):
		if int(entry["day"]) == day:
			return entry
	var weekly: Array = _data.get("weekday_themes", [])
	return weekly[(day - 1) % weekly.size()] if not weekly.is_empty() else {}


func start_day() -> void:
	_fired.clear()
	today = theme_for(WorkdayManager.day) if StoryDirector.enabled else {}


## Multiplicador o suma del día para una regla de juego.
func mod(key: String, neutral: float) -> float:
	return float(today.get("mods", {}).get(key, neutral))


func has_flag(flag: String) -> bool:
	return flag in today.get("flags", [])


func title() -> String:
	return today.get("title", "")


func lunch_override() -> Dictionary:
	return today.get("lunch", {})


func reset() -> void:
	today = {}
	_fired.clear()


func _run(beat: Dictionary) -> void:
	if beat.has("notice"):
		GameState.notice.emit(beat["notice"])
	if beat.has("stress"):
		GameState.add_stress(float(beat["stress"]))
	for id: String in beat.get("tickets", []):
		TicketQueue.add_ticket(id)
	if beat.has("event"):
		AudioDirector.play("stinger")
		EventDirector.event_started.emit(beat["event"])
	beat_fired.emit(beat)
