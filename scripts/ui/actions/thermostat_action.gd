class_name ThermostatAction
extends RepairAction
## Climatización: la temperatura deriva y hay que sostenerla dentro del rango.

const DRIFT := 0.32
const STEP := 0.07
const LOW := 0.42
const HIGH := 0.6
const HOLD_SECONDS := 1.6

var temperature := 0.85
var held := 0.0
var _drift := DRIFT
var _clock := 0.0


func begin(_param: Variant, speed: float) -> void:
	_drift = DRIFT * speed
	hint = "Izquierda enfría, derecha calienta: mantén el verde"


func tick(delta: float) -> void:
	_clock += delta
	temperature = clampf(temperature + sin(_clock * 2.3) * _drift * delta, 0.0, 1.0)
	if temperature >= LOW and temperature <= HIGH:
		held += delta
		if held >= HOLD_SECONDS:
			finished.emit(true)
	else:
		held = maxf(held - delta * 0.5, 0.0)


func handle(event: InputEvent) -> bool:
	if event.is_action_pressed("move_left"):
		temperature = clampf(temperature - STEP, 0.0, 1.0)
	elif event.is_action_pressed("move_right"):
		temperature = clampf(temperature + STEP, 0.0, 1.0)
	else:
		return false
	return true


func paint(canvas: Control, size: Vector2) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, size), INK)
	var track := Rect2(2, 3, size.x - 4, 7)
	canvas.draw_rect(track, TRACK)
	canvas.draw_rect(Rect2(track.position.x + floorf(LOW * track.size.x), 3, floorf((HIGH - LOW) * track.size.x), 7), GOOD)
	canvas.draw_rect(Rect2(track.position.x + floorf(temperature * track.size.x) - 1, 1, 3, 11), BAD if temperature > HIGH else LIGHT)
	canvas.draw_rect(Rect2(2, size.y - 5, floorf(held / HOLD_SECONDS * (size.x - 4)), 3), Color.WHITE)
