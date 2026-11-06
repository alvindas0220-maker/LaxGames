class_name ScrewsAction
extends RepairAction
## Girar un tornillo: cada cuarto de vuelta es una dirección, en sentido horario.

const ACTIONS := ["move_up", "move_right", "move_down", "move_left"]
const NAMES := ["ARRIBA", "DERECHA", "ABAJO", "IZQUIERDA"]

var turns := 4
var done := 0


func begin(param: Variant, _speed: float) -> void:
	turns = int(param)
	_update_hint()


func handle(event: InputEvent) -> bool:
	for i in ACTIONS.size():
		if event.is_action_pressed(ACTIONS[i]):
			if i == done % ACTIONS.size():
				done += 1
				_update_hint()
				if done == turns:
					finished.emit(true)
			else:
				finished.emit(false)
			return true
	return false


func paint(canvas: Control, size: Vector2) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, size), Color8(44, 48, 56))
	var center := (size / 2.0).floor()
	canvas.draw_rect(Rect2(center - Vector2(7, 7), Vector2(14, 14)), INK)
	canvas.draw_rect(Rect2(center - Vector2(6, 6), Vector2(12, 12)), Color8(160, 170, 184))
	var slot := Vector2(10, 2) if done % 2 == 0 else Vector2(2, 10)
	canvas.draw_rect(Rect2(center - slot / 2.0, slot), INK)
	for i in turns:
		canvas.draw_rect(Rect2(8 + i * 5, 4, 3, 3), LIGHT if i < done else TRACK)


func _update_hint() -> void:
	hint = "Gira el tornillo: %s" % NAMES[done % NAMES.size()]
