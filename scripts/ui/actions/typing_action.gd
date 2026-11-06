class_name TypingAction
extends RepairAction
## Teclear un comando en la consola del equipo. Los errores no castigan: la
## tecla equivocada solo se ignora, y el reloj del ticket sigue corriendo.

const ERROR_SECONDS := 0.2

var command := ""
var typed := 0
var _error := 0.0


func begin(param: Variant, _speed: float) -> void:
	command = str(param)
	hint = "Escribe el comando en la consola"


func tick(delta: float) -> void:
	_error = maxf(_error - delta, 0.0)


func handle(event: InputEvent) -> bool:
	if not event is InputEventKey or not event.pressed or event.echo or event.unicode == 0:
		return false
	if String.chr(event.unicode).to_lower() == command[typed]:
		typed += 1
		if typed == command.length():
			finished.emit(true)
	else:
		_error = ERROR_SECONDS
	return true


func paint(canvas: Control, size: Vector2) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, size), BAD.darkened(0.7) if _error > 0.0 else Color8(10, 24, 18))
	var font := canvas.get_theme_font("font", "Label")
	var origin := Vector2(4, 10)
	canvas.draw_string(font, origin, "$ ", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, GOOD)
	var done := command.left(typed)
	var x := origin.x + font.get_string_size("$ ", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	canvas.draw_string(font, Vector2(x, origin.y), done, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, GOOD)
	x += font.get_string_size(done, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	canvas.draw_string(font, Vector2(x, origin.y), command.substr(typed), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, TRACK.lightened(0.4))
