class_name PauseMenu
extends CanvasLayer
## Pausa con Esc durante la jornada: reanudar, opciones, menú principal o salir.

const ITEMS := ["reanudar", "opciones", "menu", "salir"]
const LABELS := {"reanudar": "Reanudar", "opciones": "Opciones", "menu": "Salir al menú principal", "salir": "Salir del juego"}
const LEAVE_WARNING := "Pulsa otra vez: lo de hoy se pierde. La partida se guarda cada noche al dormir."

var choice := 0
var _confirm := ""
var _opened_at := 0

@onready var _panel: Control = $Panel
@onready var _list: Label = %PauseList
@onready var _info: Label = %PauseInfo
@onready var _options: OptionsPanel = %PauseOptions


func _ready() -> void:
	_panel.hide()
	_options.closed.connect(_refresh)


func _unhandled_input(event: InputEvent) -> void:
	if _options.visible:
		return
	if not _panel.visible:
		if event.is_action_pressed("ui_cancel") and can_open():
			open()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		close()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		_select(posmod(choice - 1, ITEMS.size()))
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		_select(posmod(choice + 1, ITEMS.size()))
	elif ConfirmInput.accepted(event, _opened_at):
		get_viewport().set_input_as_handled()
		activate(ITEMS[choice])
		return
	else:
		return
	get_viewport().set_input_as_handled()


## Solo en plena jornada, sin otra ventana que ya pause el juego.
func can_open() -> bool:
	return not get_tree().paused and not GameState.input_locked and not TicketManager.repairing


func open() -> void:
	choice = 0
	_confirm = ""
	_panel.show()
	_opened_at = Time.get_ticks_msec()
	get_tree().paused = true
	_refresh()


func close() -> void:
	_panel.hide()
	get_tree().paused = false


func activate(id: String) -> void:
	match id:
		"reanudar":
			close()
		"opciones":
			_list.hide()
			_info.hide()
			_options.open()
		"menu", "salir":
			if _confirm != id:
				_confirm = id
				_info.text = LEAVE_WARNING
				return
			get_tree().paused = false
			WorkdayManager.running = false
			if id == "menu":
				get_tree().change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
			else:
				get_tree().quit()


func is_open() -> bool:
	return _panel.visible


func _select(index: int) -> void:
	choice = index
	_confirm = ""
	_refresh()


func _refresh() -> void:
	_list.visible = not _options.visible
	_info.visible = not _options.visible
	var lines := PackedStringArray(["PAUSA", ""])
	for i in ITEMS.size():
		lines.append(("> " if i == choice else "  ") + LABELS[ITEMS[i]])
	_list.text = "\n".join(lines)
	if _confirm.is_empty():
		_info.text = "%s  %s" % [WorkdayManager.label(), WorkdayManager.clock_text()]
