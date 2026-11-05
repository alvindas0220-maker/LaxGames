extends CanvasLayer
## Pantalla de despido: pausa el juego y reinicia la partida.

var _opened_at := 0

@onready var _panel: Control = $Panel


func _ready() -> void:
	_panel.hide()
	GameState.fired.connect(_on_fired)


func _unhandled_input(event: InputEvent) -> void:
	if _panel.visible and ConfirmInput.accepted(event, _opened_at):
		get_viewport().set_input_as_handled()
		get_tree().paused = false
		WorkdayManager.new_game()
		get_tree().reload_current_scene()


func _on_fired() -> void:
	_panel.show()
	_opened_at = Time.get_ticks_msec()
	get_tree().paused = true
