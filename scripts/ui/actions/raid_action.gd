class_name RaidAction
extends RepairAction
## Rack RAID: localizar cada disco en ámbar y cambiarlo en caliente.

const BAYS := 6

var failed: Array = []
var cursor := 0


func begin(param: Variant, _speed: float) -> void:
	var bays := range(BAYS)
	bays.shuffle()
	failed = bays.slice(0, int(param))
	hint = "Cambia los discos en ámbar con Espacio"


func handle(event: InputEvent) -> bool:
	if event.is_action_pressed("move_left"):
		cursor = posmod(cursor - 1, BAYS)
	elif event.is_action_pressed("move_right"):
		cursor = posmod(cursor + 1, BAYS)
	elif event.is_action_pressed("attack"):
		if cursor in failed:
			failed.erase(cursor)
			if failed.is_empty():
				finished.emit(true)
		else:
			finished.emit(false)
	else:
		return false
	return true


func paint(canvas: Control, size: Vector2) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, size), Color8(40, 44, 52))
	var left := floorf((size.x - BAYS * 22.0) / 2.0)
	for i in BAYS:
		var x := left + i * 22.0
		canvas.draw_rect(Rect2(x, 2, 18, 11), INK)
		canvas.draw_rect(Rect2(x + 1, 3, 16, 9), Color8(76, 84, 98))
		canvas.draw_rect(Rect2(x + 3, 5, 3, 3), LIGHT if i in failed else GOOD)
		if i == cursor:
			canvas.draw_rect(Rect2(x, 15, 18, 3), Color.WHITE)
