extends Node
## Lanza eventos aleatorios de oficina entre tickets.

signal event_started(event: Dictionary)

const DATA_PATH := "res://data/events.json"

var enabled := true
var rng := RandomNumberGenerator.new()
var _config := {}
var _timer := -1.0
var _last_id := ""


func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if parsed is Dictionary and parsed.get("events") is Array:
		_config = parsed
	else:
		push_error("%s no es válido" % DATA_PATH)
	rng.randomize()
	TicketManager.ticket_closed.connect(_on_ticket_closed)


func _process(delta: float) -> void:
	if _timer < 0.0:
		return
	_timer = maxf(_timer - delta, 0.0)
	# El evento espera a que no haya ningún ticket activo.
	if _timer == 0.0 and TicketManager.active == null:
		_timer = -1.0
		trigger()


func trigger() -> void:
	var events: Array = _config["events"].filter(func(e: Dictionary) -> bool: return e["id"] != _last_id)
	var event: Dictionary = events[rng.randi_range(0, events.size() - 1)]
	_last_id = event["id"]
	event_started.emit(event)


## Aplica la opción elegida y devuelve la respuesta del personaje.
func choose(event: Dictionary, index: int) -> String:
	var option: Dictionary = event["options"][index]
	GameState.add_reputation(int(option.get("reputation", 0)))
	ToolBelt.add_coffee(int(option.get("coffee", 0)))
	var warnings := int(option.get("warnings", 0))
	if warnings > 0:
		GameState.add_warning(option["label"], warnings)
	return option["reply"]


func reset() -> void:
	_timer = -1.0
	_last_id = ""


func _on_ticket_closed() -> void:
	if enabled and rng.randf() < float(_config["chance"]):
		_timer = rng.randf_range(float(_config["min_delay"]), float(_config["max_delay"]))
