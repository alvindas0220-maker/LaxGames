extends Control
## Alta de empleado: nombre primero; después, género y rasgos iniciales.

const NEXT_SCENE := "res://scenes/ui/intro_cutscene.tscn"
const GENDER_LABELS := {"hombre": "Hombre", "mujer": "Mujer"}

var gender := "hombre"
var chosen: Array = []
## Fila activa: 0 género, 1..n rasgos y la última firma el contrato.
var row := 0
var _leaving := false
var _setup_open := false
var _opened_at := 0

@onready var _name_panel: Control = $Panel
@onready var _setup_panel: Control = $Setup
@onready var _input: LineEdit = %NameInput
@onready var _perks: Label = %PerksLabel
@onready var _photo: TextureRect = %SetupPhoto
@onready var _list: Label = %SetupList
@onready var _detail: Label = %SetupDetail


func _ready() -> void:
	_setup_panel.hide()
	gender = CareerProfile.gender
	chosen = CareerProfile.traits.duplicate()
	_input.max_length = CareerProfile.MAX_NAME
	_input.text = CareerProfile.player_name if CareerProfile.player_name != CareerProfile.DEFAULT_NAME else ""
	_input.caret_column = _input.text.length()
	_input.text_changed.connect(_on_text_changed)
	_input.text_submitted.connect(submit_name)
	var perks := CareerProfile.perks_text()
	_perks.text = "Liquidación anterior: %s" % perks if not perks.is_empty() else ""
	_input.grab_focus()
	AudioDirector.play_music()


func _unhandled_input(event: InputEvent) -> void:
	if not _setup_open:
		return
	var last := CareerProfile.trait_catalog.size() + 1
	if event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		row = posmod(row - 1, last + 1)
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		row = posmod(row + 1, last + 1)
	elif row == 0 and (event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") or event.is_action_pressed("move_left") or event.is_action_pressed("move_right")):
		toggle_gender()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		if Time.get_ticks_msec() - _opened_at < ConfirmInput.MIN_OPEN_MS:
			return
		if row == last:
			# Cambiar de escena saca este nodo del árbol: se marca antes y se sale.
			_mark_handled()
			finish()
			return
		if row == 0:
			toggle_gender()
		else:
			toggle_trait(row - 1)
	else:
		return
	_refresh()
	_mark_handled()


func _mark_handled() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


## Paso 1: guarda el nombre y abre la selección de personaje.
func submit_name(text: String) -> void:
	CareerProfile.register_name(text)
	_name_panel.hide()
	_setup_panel.show()
	_setup_open = true
	_opened_at = Time.get_ticks_msec()
	_input.release_focus()
	_refresh()


func toggle_gender() -> void:
	gender = "mujer" if gender == "hombre" else "hombre"
	_refresh()


func toggle_trait(index: int) -> void:
	var id: String = CareerProfile.trait_catalog[index]["id"]
	if id in chosen:
		chosen.erase(id)
	elif chosen.size() < CareerProfile.max_traits:
		chosen.append(id)
	_refresh()


## Paso 2: firma el contrato y empieza la partida.
func finish() -> void:
	if _leaving:
		return
	_leaving = true
	CareerProfile.register_character(gender, chosen)
	SaveGame.delete()
	WorkdayManager.new_game()
	get_tree().change_scene_to_file(NEXT_SCENE)


## Completa el alta de una vez.
func confirm(text: String) -> void:
	submit_name(text)
	finish()


func _refresh() -> void:
	_photo.texture = load(CareerProfile.PORTRAITS[gender])
	var lines := PackedStringArray(["%sPersonaje: < %s >" % [_cursor(0), GENDER_LABELS[gender]], ""])
	var catalog := CareerProfile.trait_catalog
	for i in catalog.size():
		lines.append("%s[%s] %s" % [_cursor(i + 1), "x" if catalog[i]["id"] in chosen else " ", catalog[i]["name"]])
	lines.append("")
	lines.append("%sFirmar el contrato" % _cursor(catalog.size() + 1))
	_list.text = "\n".join(lines)
	if row >= 1 and row <= catalog.size():
		_detail.text = catalog[row - 1]["text"]
	else:
		_detail.text = "Elige hasta %d rasgos. Rasgos: %d" % [CareerProfile.max_traits, chosen.size()]


func _cursor(index: int) -> String:
	return "> " if index == row else "  "


func _on_text_changed(text: String) -> void:
	var clean := CareerProfile.clean_name(text)
	if clean != text:
		var caret := _input.caret_column
		_input.text = clean
		_input.caret_column = mini(caret, clean.length())
