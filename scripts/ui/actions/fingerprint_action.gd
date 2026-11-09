class_name FingerprintAction
extends RepairAction
## Lector biométrico: recolocar los puntos de la huella hasta igualar la plantilla.

const COLS := 5
const ROWS := 3
const MARKS := 5
const MOVES := {"move_left": Vector2i.LEFT, "move_right": Vector2i.RIGHT, "move_up": Vector2i.UP, "move_down": Vector2i.DOWN}

var template := {}
var current := {}
var cursor := Vector2i.ZERO


func begin(_param: Variant, _speed: float) -> void:
	var cells: Array[Vector2i] = []
	for y in ROWS:
		for x in COLS:
			cells.append(Vector2i(x, y))
	cells.shuffle()
	for cell in cells.slice(0, MARKS):
		template[cell] = true
	hint = "Marca con Espacio los puntos de la plantilla"


func handle(event: InputEvent) -> bool:
	for action: String in MOVES:
		if event.is_action_pressed(action):
			cursor = (cursor + MOVES[action]).clamp(Vector2i.ZERO, Vector2i(COLS - 1, ROWS - 1))
			return true
	if event.is_action_pressed("attack"):
		if current.has(cursor):
			current.erase(cursor)
		else:
			current[cursor] = true
		if current.size() == template.size() and current.keys().all(func(c: Vector2i) -> bool: return template.has(c)):
			finished.emit(true)
		return true
	return false


func paint(canvas: Control, size: Vector2) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, size), INK)
	_paint_grid(canvas, Vector2(30, 2), template, Color8(110, 200, 240), false)
	_paint_grid(canvas, Vector2(size.x - 72.0, 2), current, GOOD, true)


func _paint_grid(canvas: Control, origin: Vector2, marks: Dictionary, color: Color, show_cursor: bool) -> void:
	for y in ROWS:
		for x in COLS:
			var cell := Vector2i(x, y)
			var at := origin + Vector2(cell) * 6.0
			canvas.draw_rect(Rect2(at, Vector2(5, 5)), color if marks.has(cell) else TRACK)
			if show_cursor and cell == cursor:
				canvas.draw_rect(Rect2(at + Vector2(1, 1), Vector2(3, 3)), Color.WHITE)
