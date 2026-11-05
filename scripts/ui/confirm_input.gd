class_name ConfirmInput
extends RefCounted
## Confirmación de ventanas que no deben cerrarse por accidente.
## Espacio no cuenta, porque es la tecla de usar herramienta, y se ignora
## cualquier pulsación justo después de abrir la ventana.

const MIN_OPEN_MS := 400


static func accepted(event: InputEvent, opened_at_ms: int) -> bool:
	if Time.get_ticks_msec() - opened_at_ms < MIN_OPEN_MS:
		return false
	if event is InputEventKey and event.keycode == KEY_SPACE:
		return false
	return event.is_action_pressed("ui_accept") or event.is_action_pressed("interact")
