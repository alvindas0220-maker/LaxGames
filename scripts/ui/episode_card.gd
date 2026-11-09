class_name EpisodeCard
extends CanvasLayer
## Cortinilla de cada mañana: título del episodio, lo anterior y el rumor del día.

var _opened_at := 0

@onready var _panel: Control = $Panel
@onready var _number: Label = %EpisodeNumber
@onready var _title: Label = %EpisodeTitle
@onready var _recap: Label = %EpisodeRecap
@onready var _rumor: Label = %EpisodeRumor
@onready var _teaser: Label = %EpisodeTeaser
@onready var _theme: Label = %EpisodeTheme


func _ready() -> void:
	_panel.hide()


func _unhandled_input(event: InputEvent) -> void:
	if not _panel.visible or not ConfirmInput.accepted(event, _opened_at):
		return
	get_viewport().set_input_as_handled()
	_panel.hide()
	get_tree().paused = false


func present(episode: Dictionary) -> void:
	_number.text = "EPISODIO %d" % WorkdayManager.day
	_title.text = episode["title"]
	_recap.text = "Anteriormente: %s" % episode["recap"]
	_rumor.text = episode["rumor"]
	_teaser.text = episode["teaser"]
	var theme := DayEvents.today
	_theme.text = "Hoy: %s. %s" % [theme["title"], theme["intro"]] if not theme.is_empty() else ""
	_panel.show()
	_opened_at = Time.get_ticks_msec()
	get_tree().paused = true
	AudioDirector.play("stinger")
