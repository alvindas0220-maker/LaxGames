class_name NightMenu
extends CanvasLayer
## Noche en casa: trabajos extra por dinero, tienda en el celular y dormir.

const DATA_PATH := "res://data/gigs.json"
const CURSOR := "> "

var offers: Array = []
var done_tonight := 0
var _config := {}
var _choice := 0
var _opened_at := 0
var _rng := RandomNumberGenerator.new()

@onready var _panel: Control = $Panel
@onready var _info: Label = %NightInfo
@onready var _list: Label = %NightList
@onready var _result: Label = %NightResult
@onready var _bar: RepairBar = get_node("../RepairBar")


func _ready() -> void:
	_panel.hide()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if parsed is Dictionary:
		_config = parsed
	else:
		push_error("%s no es válido" % DATA_PATH)
	_rng.randomize()
	WorkdayManager.night_started.connect(open)
	_bar.gig_finished.connect(_on_gig_finished)


func _unhandled_input(event: InputEvent) -> void:
	if not _panel.visible or _phone_open():
		return
	var count := _options_count()
	if event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		_choice = posmod(_choice - 1, count)
		_redraw_list()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		_choice = posmod(_choice + 1, count)
		_redraw_list()
	elif ConfirmInput.accepted(event, _opened_at):
		# Dormir recarga la escena: hay que marcar la tecla antes de confirmar.
		get_viewport().set_input_as_handled()
		_confirm()
		return
	else:
		return
	get_viewport().set_input_as_handled()


func open() -> void:
	GameState.night = true
	done_tonight = 0
	_choice = 0
	var pool: Array = _config["gigs"].duplicate()
	offers.clear()
	for i in int(_config["offers"]):
		offers.append(pool.pop_at(_rng.randi_range(0, pool.size() - 1)))
	_result.text = "Tab o la opción Tienda abren el celular."
	_refresh()
	_panel.show()
	_opened_at = Time.get_ticks_msec()


## Acepta un trabajo: abre el minijuego de su herramienta.
func start_gig(index: int) -> void:
	var gig: Dictionary = offers[index]
	if done_tonight >= int(_config["max_per_night"]):
		_result.text = "Ya no quedan horas esta noche."
	elif GameState.stress + float(gig["stress"]) >= GameState.MAX_STRESS - 5.0:
		_result.text = "Con tanto estrés no puedes aceptar más trabajo."
	else:
		_panel.hide()
		_bar.start_gig(gig["name"], gig["tool"], int(gig["rounds"]))


func sleep() -> void:
	GameState.night = false
	_panel.hide()
	get_tree().paused = false
	WorkdayManager.next_day()
	get_tree().reload_current_scene()


func _confirm() -> void:
	if _choice < offers.size():
		start_gig(_choice)
	elif _choice == offers.size():
		get_tree().call_group("phone", "open", Phone.SHOP_TAB)
	else:
		sleep()


func _on_gig_finished(completed: bool, misses: int) -> void:
	_panel.show()
	_opened_at = Time.get_ticks_msec()
	if not completed:
		_result.text = "Dejaste el trabajo a medias."
		return
	var gig: Dictionary = offers.pop_at(_choice)
	done_tonight += 1
	var quality := maxf(1.0 - float(_config["miss_penalty"]) * misses, 0.3)
	var pay := roundi(float(gig["pay"]) * quality)
	GameState.add_money(pay)
	GameState.add_stress(float(gig["stress"]))
	_result.text = "%s te paga $%d." % [gig["client"], pay]
	_choice = mini(_choice, _options_count() - 1)
	_refresh()


func _refresh() -> void:
	_info.text = "%s, %s  Dinero: $%d  Estrés: %d%%  Trabajos: %d de %d" % [
		CareerProfile.player_name, WorkdayManager.label(), GameState.money, GameState.stress, done_tonight, int(_config["max_per_night"]),
	]
	_redraw_list()


func _redraw_list() -> void:
	var lines := PackedStringArray()
	for gig: Dictionary in offers:
		lines.append("%s - %s" % [gig["client"], gig["name"]])
		lines.append("   $%d, %s, +%d de estrés" % [gig["pay"], ToolBelt.TOOL_SHORT[gig["tool"]], gig["stress"]])
	var marked := PackedStringArray()
	var row := 0
	for i in offers.size():
		marked.append((CURSOR if i == _choice else "  ") + lines[row])
		marked.append(lines[row + 1])
		row += 2
	marked.append((CURSOR if _choice == offers.size() else "  ") + "Tienda de mejoras")
	marked.append((CURSOR if _choice == offers.size() + 1 else "  ") + "Dormir hasta mañana")
	_list.text = "\n".join(marked)


func _options_count() -> int:
	return offers.size() + 2


func _phone_open() -> bool:
	var phone := get_tree().get_first_node_in_group("phone") as Phone
	return phone != null and phone.is_open()
