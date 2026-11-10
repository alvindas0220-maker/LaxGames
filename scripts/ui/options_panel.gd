class_name OptionsPanel
extends PanelContainer
## Opciones compartidas por el menú principal y la pausa.

signal closed

const ROWS := ["musica", "efectos", "pantalla", "volver"]

var row := 0
var _opened_at := 0

@onready var _list: Label = %OptionsList


func _ready() -> void:
	hide()


func open() -> void:
	row = 0
	show()
	_opened_at = Time.get_ticks_msec()
	_refresh()


func close() -> void:
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		row = posmod(row - 1, ROWS.size())
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		row = posmod(row + 1, ROWS.size())
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		adjust(-1)
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		adjust(1)
	elif ConfirmInput.accepted(event, _opened_at):
		if ROWS[row] == "volver":
			close()
			get_viewport().set_input_as_handled()
			return
		adjust(1)
	else:
		return
	_refresh()
	get_viewport().set_input_as_handled()


## Cambia la opción de la fila activa hacia un lado.
func adjust(step: int) -> void:
	match ROWS[row]:
		"musica":
			Settings.set_music(Settings.music + step * Settings.STEP)
		"efectos":
			Settings.set_sfx(Settings.sfx + step * Settings.STEP)
		"pantalla":
			Settings.set_fullscreen(not Settings.fullscreen)
	_refresh()


func _refresh() -> void:
	var values := {
		"musica": "Música      < %d%% >" % roundi(Settings.music * 100.0),
		"efectos": "Efectos     < %d%% >" % roundi(Settings.sfx * 100.0),
		"pantalla": "Pantalla completa: %s" % ("Sí" if Settings.fullscreen else "No"),
		"volver": "Volver",
	}
	var lines := PackedStringArray(["OPCIONES", ""])
	for i in ROWS.size():
		lines.append(("> " if i == row else "  ") + values[ROWS[i]])
	_list.text = "\n".join(lines)
