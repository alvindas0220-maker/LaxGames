class_name BeepAction
extends RepairAction
## Estación de trabajo: repetir el código de pitidos del arranque.

const ACTIONS := ["move_up", "move_right", "move_down", "move_left"]
const BEEP_SECONDS := 0.5

var code: Array = []
var entered := 0
var showing := true
var _shown := 0
var _left := BEEP_SECONDS


func begin(param: Variant, _speed: float) -> void:
	for i in int(param):
		code.append(randi() % ACTIONS.size())
	hint = "Observa el código de arranque"


func tick(delta: float) -> void:
	if not showing:
		return
	_left -= delta
	if _left <= 0.0:
		_left = BEEP_SECONDS
		_shown += 1
		if _shown >= code.size():
			showing = false
			hint = "Repite el código con las direcciones"


func handle(event: InputEvent) -> bool:
	if showing:
		return false
	for i in ACTIONS.size():
		if event.is_action_pressed(ACTIONS[i]):
			if i == code[entered]:
				entered += 1
				if entered == code.size():
					finished.emit(true)
			else:
				finished.emit(false)
			return true
	return false


func paint(canvas: Control, size: Vector2) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, size), INK)
	var center := (size / 2.0).floor()
	var offsets := [Vector2(0, -6), Vector2(8, 0), Vector2(0, 6), Vector2(-8, 0)]
	var lit: int = code[_shown] if showing and _left > 0.14 else -1
	for i in offsets.size():
		canvas.draw_rect(Rect2(center + offsets[i] - Vector2(3, 2), Vector2(6, 4)), LIGHT if i == lit else TRACK)
	for i in code.size():
		canvas.draw_rect(Rect2(6 + i * 6, 4, 4, 4), GOOD if i < entered else TRACK)
