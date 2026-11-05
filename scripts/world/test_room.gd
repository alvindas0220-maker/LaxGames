extends Node2D
## Sala de pruebas. H añade una amonestación.


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and (event as InputEventKey).physical_keycode == KEY_H:
		GameState.add_warning("prueba")
