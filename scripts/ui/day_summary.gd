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
		_panel.hide()
		get_tree().paused = true
		WorkdayManager.night_started.emit()


func _on_day_ended(summary: Dictionary) -> void:
	_finished = summary["finished"]
	var header: String = "FIN DE LA HISTORIA" if _finished else "FIN DE LA JORNADA"
	var action: String = "Pulsa Enter para una partida nueva" if _finished else "Pulsa Enter para pasar la noche"
	var lines := PackedStringArray([
		"%s  -  Calificación %s" % [header, summary["grade"]],
		"%s, %s" % [summary["employee"], summary["label"]],
		summary["phase"],
		"",
		"Tickets %d de %d   Perdidos %d" % [summary["tickets"], summary["quota"], summary["lost"]],
		"Tiempo medio %d s   Precisión %d%%" % [summary["average"], summary["accuracy"]],
		"Errores de herramienta %d" % summary["tool_errors"],
		"Estrés %d%%, con pico de %d%%" % [summary["stress"], summary["stress_peak"]],
		"Reputación %d%% (%+.1f)" % [summary["reputation"], summary["gain"]],
		"Expediente: %s" % summary["warning"],
		"Puesto: %s" % summary["title"],
		"Sueldo $%d + extras $%d = ahorros $%d" % [summary["salary"], summary["extra"], summary["money"]],
		"",
		summary["brief"],
		action,
	])
	_label.text = "\n".join(lines)
	_panel.show()
	_opened_at = Time.get_ticks_msec()
	get_tree().paused = true
