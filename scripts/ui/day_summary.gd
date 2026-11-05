extends CanvasLayer
## Resumen al acabar la jornada, y pantalla final al llegar al 200 %.

var _finished := false
var _opened_at := 0

@onready var _panel: Control = $Panel
@onready var _label: Label = %SummaryLabel


func _ready() -> void:
	_panel.hide()
	WorkdayManager.day_ended.connect(_on_day_ended)


func _unhandled_input(event: InputEvent) -> void:
	if not _panel.visible or not ConfirmInput.accepted(event, _opened_at):
		return
	get_viewport().set_input_as_handled()
	get_tree().paused = false
	if _finished:
		WorkdayManager.new_game()
		get_tree().change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	else:
		WorkdayManager.next_day()
		get_tree().reload_current_scene()


func _on_day_ended(summary: Dictionary) -> void:
	_finished = summary["finished"]
	var header: String = "FIN DE LA HISTORIA" if _finished else "FIN DE LA JORNADA"
	var action: String = "Pulsa Enter para una partida nueva" if _finished else "Pulsa Enter para la siguiente jornada"
	_label.text = "%s\n%s\n\nTickets: %d\nReputación: %d%% (%+d)\nExpediente: %s\nPuesto: %s\n\n%s\n\n%s" % [
		header, summary["label"], summary["tickets"], summary["reputation"], summary["gain"],
		summary["warning"], summary["title"], summary["brief"], action,
	]
	_panel.show()
	_opened_at = Time.get_ticks_msec()
	get_tree().paused = true
