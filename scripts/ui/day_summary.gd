extends CanvasLayer
## Resumen al acabar la jornada, y pantalla final al llegar al 200 %.

const EPILOGUE := "res://scenes/ui/epilogue.tscn"

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
		get_tree().change_scene_to_file(EPILOGUE)
	else:
		_panel.hide()
		get_tree().paused = true
		WorkdayManager.night_started.emit()


func _on_day_ended(summary: Dictionary) -> void:
	_finished = summary["finished"]
	if _finished:
		SaveGame.delete()
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
		"Vida social: %d charlas" % summary["social"],
		"Puesto: %s" % summary["title"],
		"Sueldo $%d + extras $%d - gastos $%d = ahorros $%d" % [summary["salary"], summary["extra"], summary["expenses"], summary["money"]],
		"Deuda: $%d. Mañana te pesará." % summary["debt"] if summary["debt"] > 0 else "",
		"",
		summary["brief"],
		action,
	])
	_label.text = "\n".join(lines)
	_panel.show()
	_opened_at = Time.get_ticks_msec()
	get_tree().paused = true
