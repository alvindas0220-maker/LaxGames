class_name StoryScene
extends CanvasLayer
## Escena de la trama: fondo, dos retratos enfrentados y diálogo letra a letra.
## Pausa el juego mientras dura y avisa al terminar.

signal finished

const CHARS_PER_SECOND := 40.0
const DIM := Color(0.45, 0.45, 0.55)
const PLAYER_ID := "alex"

var _lines: Array = []
var _index := -1
var _shown := 0.0
var _opened_at := 0

@onready var _panel: Control = $Panel
@onready var _back: TextureRect = %SceneBack
@onready var _left: TextureRect = %SceneLeft
@onready var _right: TextureRect = %SceneRight
@onready var _speaker: Label = %SceneSpeaker
@onready var _text: Label = %SceneText


func _ready() -> void:
	add_to_group("story_scene")
	_panel.hide()


func _process(delta: float) -> void:
	if not _panel.visible or _text.visible_characters >= _text.text.length():
		return
	_shown += delta * CHARS_PER_SECOND
	_text.visible_characters = mini(int(_shown), _text.text.length())


func _unhandled_input(event: InputEvent) -> void:
	if not _panel.visible or not ConfirmInput.accepted(event, _opened_at):
		return
	get_viewport().set_input_as_handled()
	if _text.visible_characters < _text.text.length():
		_text.visible_characters = _text.text.length()
	else:
		_next()


func play(scene: Dictionary) -> void:
	_lines = scene["lines"]
	_index = -1
	_back.texture = load("res://assets/sprites/scenes/%s.png" % scene["place"])
	var speakers: Array = []
	for line: Array in _lines:
		if not line[0] in speakers:
			speakers.append(line[0])
	_left.texture = NpcDatabase.portrait_of(speakers[0])
	_right.texture = NpcDatabase.portrait_of(speakers[1]) if speakers.size() > 1 else null
	_left.set_meta("speaker", speakers[0])
	_right.set_meta("speaker", speakers[1] if speakers.size() > 1 else "")
	_panel.show()
	_opened_at = Time.get_ticks_msec()
	get_tree().paused = true
	_next()


func is_playing() -> bool:
	return _panel.visible


func _next() -> void:
	_index += 1
	if _index >= _lines.size():
		_panel.hide()
		get_tree().paused = false
		finished.emit()
		return
	var line: Array = _lines[_index]
	var speaker_id: String = line[0]
	_speaker.text = CareerProfile.player_name if speaker_id == PLAYER_ID else NpcDatabase.get_npc(speaker_id).get("name", "")
	_text.text = CareerProfile.format(line[1])
	_text.visible_characters = 0
	_shown = 0.0
	_left.modulate = Color.WHITE if _left.get_meta("speaker") == speaker_id else DIM
	_right.modulate = Color.WHITE if _right.get_meta("speaker") == speaker_id else DIM
