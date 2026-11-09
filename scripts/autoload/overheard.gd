extends Node
## Conversaciones de pasillo: al pasar por ciertas zonas se oye a otros hablar.
## No pausa el juego; las frases aparecen una tras otra en el cuadro de diálogo.

signal finished(id: String)

const LINE_SECONDS := 3.2
const ZONE_COOLDOWN := 25.0

var playing := {}
var _queue: Array = []
var _left := 0.0
var _seen := {}
var _cooldown := {}


func _process(delta: float) -> void:
	for zone: String in _cooldown.keys():
		_cooldown[zone] -= delta
		if _cooldown[zone] <= 0.0:
			_cooldown.erase(zone)
	if playing.is_empty():
		return
	_left -= delta
	if _left <= 0.0:
		_next_line()


## El protagonista entra en una zona: se oye la primera charla disponible.
func overhear(zone: String) -> bool:
	if not StoryDirector.enabled or not playing.is_empty() or _cooldown.has(zone):
		return false
	for talk: Dictionary in DayEvents.data().get("overheard", []):
		if talk["zone"] == zone and not _seen.has(talk["id"]) and StoryDirector.is_available(talk.get("requires", {})):
			_seen[talk["id"]] = true
			_cooldown[zone] = ZONE_COOLDOWN
			playing = talk
			_queue = talk["lines"].duplicate()
			_next_line()
			return true
	return false


func reset() -> void:
	playing = {}
	_queue.clear()
	_seen.clear()
	_cooldown.clear()


func _next_line() -> void:
	if _queue.is_empty():
		var talk := playing
		playing = {}
		StoryDirector.discover(talk.get("clue", ""))
		finished.emit(talk["id"])
		return
	var line: Array = _queue.pop_front()
	_left = LINE_SECONDS
	DialogueManager.overheard(line[0], line[1])
