extends CanvasLayer
## Pantalla de despido. Sin responsabilidad patronal se pierde todo y vuelve al
## inicio; con responsabilidad se cobra la liquidación y se repite con ventajas.

const FOR_CAUSE_TEXT := "DESPIDO SIN RESPONSABILIDAD PATRONAL\n\n%s\n\nRR. HH. te acompaña a la salida, %s. Sin liquidación ni carta de recomendación.\n\nPulsa Enter para empezar de cero"
const SEVERANCE_TEXT := "DESPIDO CON RESPONSABILIDAD\n\n%s, tu expediente llegó a tres faltas.\nLaxCorp te paga tu liquidación.\n\nEn tu próxima contratación: %s.\n\nPulsa Enter para volver a empezar"

var _opened_at := 0
var _strict := false

@onready var _panel: Control = $Panel
@onready var _label: Label = $Panel/Label


func _ready() -> void:
	_panel.hide()
	GameState.fired.connect(_on_fired)


func _unhandled_input(event: InputEvent) -> void:
	if not _panel.visible or not ConfirmInput.accepted(event, _opened_at):
		return
	get_viewport().set_input_as_handled()
	get_tree().paused = false
	WorkdayManager.new_game()
	if _strict:
		get_tree().change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	else:
		get_tree().reload_current_scene()


func _on_fired() -> void:
	_strict = GameState.fired_for_cause
	if _strict:
		CareerProfile.fired_for_cause()
		_label.text = FOR_CAUSE_TEXT % [GameState.slip_line, CareerProfile.player_name]
	else:
		CareerProfile.fired_with_severance()
		_label.text = SEVERANCE_TEXT % [CareerProfile.player_name, CareerProfile.perks_text()]
	_panel.show()
	_opened_at = Time.get_ticks_msec()
	get_tree().paused = true
