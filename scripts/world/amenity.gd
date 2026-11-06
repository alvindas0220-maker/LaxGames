class_name Amenity
extends Interactable
## Baños y sofás: bajan el estrés a cambio de minutos de la jornada.

@export var relief := 12.0
## Segundos del reloj de jornada que cuesta el descanso.
@export var clock_cost := 12.0
@export var cooldown := 45.0
@export var rest_text := "Respiras hondo."

var _ready_at := 0


func interact() -> void:
	var now := Time.get_ticks_msec()
	if now < _ready_at:
		GameState.notice.emit("Acabas de descansar aquí. Vuelve al trabajo.")
		return
	_ready_at = now + int(cooldown * 1000.0)
	GameState.add_stress(-relief)
	if WorkdayManager.running:
		WorkdayManager.clock += clock_cost
	GameState.notice.emit("%s Estrés al %d%%." % [rest_text, GameState.stress])
