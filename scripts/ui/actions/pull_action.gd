class_name PullAction
extends RepairAction
## Extraer una pieza con cuidado: mantener Espacio sin pasarse de fuerza.

const RISE := 0.9
const FALL := 1.4
const SAFE_LOW := 0.45
const SAFE_HIGH := 0.82
const BREAK_AT := 0.98
const PULL_SECONDS := 1.3

var tension := 0.0
var progress := 0.0
var _holding := false
var _speed := 1.0


func begin(_param: Variant, speed: float) -> void:
	_speed = speed
	hint = "Mantén Espacio en verde, sin pasarte"


func tick(delta: float) -> void:
	tension = clampf(tension + (RISE * _speed if _holding else -FALL) * delta, 0.0, 1.0)
	if tension >= BREAK_AT:
		_holding = false
		finished.emit(false)
	elif tension >= SAFE_LOW and tension <= SAFE_HIGH:
		progress += delta / PULL_SECONDS
		if progress >= 1.0:
			_holding = false
			finished.emit(true)


func handle(event: InputEvent) -> bool:
	if event.is_action_pressed("attack"):
		_holding = true
		return true
	if event.is_action_released("attack"):
		_holding = false
		return true
	return false


func paint(canvas: Control, size: Vector2) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, size), INK)
	var track := Rect2(2, 3, size.x - 4, 6)
	canvas.draw_rect(track, TRACK)
	canvas.draw_rect(Rect2(track.position.x + floorf(SAFE_LOW * track.size.x), 3, floorf((SAFE_HIGH - SAFE_LOW) * track.size.x), 6), GOOD)
	canvas.draw_rect(Rect2(track.position.x + floorf(tension * track.size.x) - 1, 1, 3, 10), LIGHT)
	canvas.draw_rect(Rect2(2, size.y - 5, floorf(progress * (size.x - 4)), 3), Color8(244, 244, 248))
