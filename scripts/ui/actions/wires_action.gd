class_name WiresAction
extends RepairAction
## Conectar los hilos de un cable UTP en el orden que marca el esquema.

const COLORS := [Color8(44, 106, 208), Color8(232, 140, 40), Color8(80, 224, 128), Color8(150, 90, 50)]

var order: Array = []
var done := 0


func begin(_param: Variant, _speed: float) -> void:
	order = [0, 1, 2, 3]
	order.shuffle()
	hint = "Pulsa 1 a 4 en el orden de los colores"


func handle(event: InputEvent) -> bool:
	for i in COLORS.size():
		if event.is_action_pressed("slot_%d" % (i + 1)):
			if i == order[done]:
				done += 1
				if done == order.size():
					finished.emit(true)
			else:
				finished.emit(false)
			return true
	return false


func paint(canvas: Control, size: Vector2) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, size), INK)
	var font := canvas.get_theme_font("font", "Label")
	for i in order.size():
		var box := Rect2(6 + i * 22, 3, 18, 8)
		canvas.draw_rect(box, COLORS[order[i]] if i >= done else TRACK)
	for i in COLORS.size():
		var x := size.x - 88.0 + i * 22.0
		canvas.draw_rect(Rect2(x, 4, 8, 6), COLORS[i])
		canvas.draw_string(font, Vector2(x + 10.0, 10.0), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
