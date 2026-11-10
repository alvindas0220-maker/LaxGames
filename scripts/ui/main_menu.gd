extends Control
## Menú principal: continuar la partida guardada, empezar otra, opciones y créditos.

const NAME_SCENE := "res://scenes/ui/name_entry.tscn"
const OFFICE_SCENE := "res://scenes/world/office.tscn"
const LABELS := {
	"continuar": "Continuar", "nueva": "Nueva partida", "opciones": "Opciones",
	"creditos": "Créditos", "salir": "Salir",
}

var items: Array = []
var choice := 0
var _confirm_overwrite := false
var _leaving := false
var _opened_at := 0

@onready var _list: Label = %MenuList
@onready var _info: Label = %MenuInfo
@onready var _options: OptionsPanel = %Options
@onready var _credits: Control = %Credits


func _ready() -> void:
	# Ninguna ventana de la partida anterior debe dejar el juego en pausa aquí.
	get_tree().paused = false
	GameState.input_locked = false
	AudioDirector.play_music()
	_credits.hide()
	_options.closed.connect(_refresh)
	items = ["continuar"] if SaveGame.has_save() else []
	items.append_array(["nueva", "opciones", "creditos", "salir"])
	_opened_at = Time.get_ticks_msec()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if _options.visible or _leaving:
		return
	if _credits.visible:
		if event.is_action_pressed("ui_cancel") or ConfirmInput.accepted(event, _opened_at):
			_credits.hide()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		select(posmod(choice - 1, items.size()))
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		select(posmod(choice + 1, items.size()))
	elif ConfirmInput.accepted(event, _opened_at):
		get_viewport().set_input_as_handled()
		activate(items[choice])
		return
	else:
		return
	get_viewport().set_input_as_handled()


func select(index: int) -> void:
	choice = index
	_confirm_overwrite = false
	_refresh()


func select_id(id: String) -> void:
	select(items.find(id))


func activate(id: String) -> void:
	match id:
		"continuar":
			if SaveGame.load_game():
				_leave(OFFICE_SCENE)
			else:
				_info.text = "No se pudo cargar la partida guardada."
		"nueva":
			if SaveGame.has_save() and not _confirm_overwrite:
				_confirm_overwrite = true
				_info.text = "Pulsa otra vez: se borrará la partida guardada."
				return
			SaveGame.delete()
			_leave(NAME_SCENE)
		"opciones":
			_options.open()
		"creditos":
			_credits.show()
			_opened_at = Time.get_ticks_msec()
		"salir":
			get_tree().quit()


func _leave(scene: String) -> void:
	_leaving = true
	get_tree().change_scene_to_file(scene)


func _refresh() -> void:
	var lines := PackedStringArray()
	for i in items.size():
		lines.append(("> " if i == choice else "  ") + LABELS[items[i]])
	_list.text = "\n".join(lines)
	if not _confirm_overwrite:
		_info.text = "Partida guardada: %s" % SaveGame.saved_summary() if SaveGame.has_save() else ""
