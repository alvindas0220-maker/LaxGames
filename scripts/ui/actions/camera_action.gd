class_name CameraAction
extends RepairAction
## Cámara desconfigurada: mover el encuadre hasta centrar el punto marcado.

const STEP := 6.0
const AREA := Vector2(180, 18)
const TOLERANCE := 7.0
const MOVES := {"move_left": Vector2.LEFT, "move_right": Vector2.RIGHT, "move_up": Vector2.UP, "move_down": Vector2.DOWN}

var aim := Vector2.ZERO
var mark := Vector2.ZERO


func begin(_param: Variant, _speed: float) -> void:
	aim = Vector2(STEP * 2.0, 6.0)
	mark = Vector2(randf_range(60.0, AREA.x - 10.0), randf_range(4.0, AREA.y - 4.0))
	hint = "Encuadra el punto rojo y fija con Espacio"


func handle(event: InputEvent) -> bool:
	for action: String in MOVES:
		if event.is_action_pressed(action):
			aim = (aim + MOVES[action] * STEP).clamp(Vector2.ZERO, AREA)
			return true
	if event.is_action_pressed("attack"):
		finished.emit(aim.distance_to(mark) <= TOLERANCE)
		return true
	return false


func paint(canvas: Control, size: Vector2) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, size), Color8(22, 34, 30))
	canvas.draw_rect(Rect2(mark.round() - Vector2.ONE, Vector2(3, 3)), BAD)
	var box := aim.round()
	var ink := GOOD if aim.distance_to(mark) <= TOLERANCE else Color.WHITE
	canvas.draw_rect(Rect2(box - Vector2(5, 1), Vector2(3, 1)), ink)
	canvas.draw_rect(Rect2(box + Vector2(3, -1), Vector2(3, 1)), ink)
	canvas.draw_rect(Rect2(box - Vector2(1, 5), Vector2(1, 3)), ink)
	canvas.draw_rect(Rect2(box + Vector2(-1, 3), Vector2(1, 3)), ink)
