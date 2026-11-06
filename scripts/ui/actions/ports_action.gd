class_name PortsAction
extends RepairAction
## Encontrar en el panel el puerto sin señal y probarlo con el tester.

const COUNT := 8

var dead := 0
var cursor := 0


func begin(_param: Variant, _speed: float) -> void:
	dead = randi() % COUNT
	cursor = (dead + 1 + randi() % (COUNT - 1)) % COUNT
	hint = "Busca el puerto apagado: Espacio"


func handle(event: InputEvent) -> bool:
	if event.is_action_pressed("move_left"):
		cursor = posmod(cursor - 1, COUNT)
	elif event.is_action_pressed("move_right"):
		cursor = posmod(cursor + 1, COUNT)
	elif event.is_action_pressed("attack"):
		finished.emit(cursor == dead)
	else:
		return false
	return true


func paint(canvas: Control, size: Vector2) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, size), Color8(44, 48, 56))
	var left := floorf((size.x - COUNT * 16.0) / 2.0)
	var blink := Time.get_ticks_msec() / 200 % 2 == 0
	for i in COUNT:
		var x := left + i * 16.0
		canvas.draw_rect(Rect2(x, 4, 12, 8), INK)
		if i != dead:
			canvas.draw_rect(Rect2(x + 2, 5, 2, 2), GOOD if blink or i % 2 == 0 else GOOD.darkened(0.5))
		if i == cursor:
			canvas.draw_rect(Rect2(x, 14, 12, 3), LIGHT)
