class_name CipherAction
extends TypingAction
## Portátil cifrado: la contraseña aparece con cada letra desplazada; hay que descifrarla.

const ALPHABET := "abcdefghijklmnopqrstuvwxyz"

var shift := 1
var encoded := ""


func begin(param: Variant, speed: float) -> void:
	super.begin(param, speed)
	shift = 1 + randi() % 3
	encoded = ""
	for character in command:
		encoded += ALPHABET[(ALPHABET.find(character) + shift) % ALPHABET.length()]
	hint = "Cada letra avanzó %d: escribe la original" % shift


func paint(canvas: Control, size: Vector2) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, size), BAD.darkened(0.7) if _error > 0.0 else Color8(18, 20, 40))
	var font := canvas.get_theme_font("font", "Label")
	canvas.draw_string(font, Vector2(4, 8), encoded, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, LIGHT)
	canvas.draw_string(font, Vector2(70, 8), command.left(typed) + "_".repeat(0), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, GOOD)
	for i in command.length():
		canvas.draw_rect(Rect2(70 + i * 6, 11, 5, 1), GOOD if i < typed else TRACK)
