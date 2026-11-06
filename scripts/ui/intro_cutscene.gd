extends Control
## Cinemática inicial tipo novela visual: lee sus líneas de data/intro.json.
## E, Enter o Espacio completan la línea o avanzan. Escape la salta.

const DATA_PATH := "res://data/intro.json"
const PLAYER_ID := "alex"
const NEXT_SCENE := "res://scenes/world/office.tscn"
const CHARS_PER_SECOND := 34.0
const BLIP_EVERY := 3
## Ignora la tecla con la que se llegó a esta pantalla.
const INPUT_GUARD_MS := 300
const SOUNDS := {
	"keyboard": preload("res://assets/audio/keyboard.wav"),
	"phone": preload("res://assets/audio/phone.wav"),
	"stamp": preload("res://assets/audio/stamp.wav"),
	"alarm": preload("res://assets/audio/alarm.wav"),
}

var _lines: Array = []
var _index := -1
var _shown := 0.0
var _last_blip := 0
var _leaving := false
var _opened_at := 0

@onready var _label: Label = %StoryLabel
@onready var _hint: Label = %HintLabel
@onready var _speaker: Label = %SpeakerName
@onready var _portrait: TextureRect = %SpeakerPortrait
@onready var _alert: ColorRect = $Alert
@onready var _blackout: ColorRect = $Blackout
@onready var _sfx: AudioStreamPlayer = $Sfx
@onready var _blip: AudioStreamPlayer = $Blip


func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	_lines = parsed["lines"] if parsed is Dictionary else []
	AudioDirector.play_music()
	_opened_at = Time.get_ticks_msec()
	var hero: TextureRect = $Hero
	if hero.texture is AtlasTexture:
		var frame: AtlasTexture = hero.texture.duplicate()
		frame.atlas = load(CareerProfile.sheet_path())
		hero.texture = frame
	_next_line()


func _process(delta: float) -> void:
	if _alert.visible:
		var pulse := sin(Time.get_ticks_msec() * 0.009)
		_alert.color.a = 0.14 + 0.1 * pulse
		# Parpadeo irregular de las luces durante la caída del servidor.
		_blackout.visible = sin(Time.get_ticks_msec() * 0.031) > 0.82
	var total := _label.text.length()
	if _label.visible_characters < 0 or _label.visible_characters >= total:
		_hint.visible = true
		return
	_shown += delta * CHARS_PER_SECOND
	_label.visible_characters = mini(int(_shown), total)
	if _label.visible_characters - _last_blip >= BLIP_EVERY:
		_last_blip = _label.visible_characters
		_blip.play()


func _unhandled_input(event: InputEvent) -> void:
	if _leaving or Time.get_ticks_msec() - _opened_at < INPUT_GUARD_MS:
		return
	if event.is_action_pressed("ui_cancel"):
		_finish()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		if _label.visible_characters < _label.text.length():
			_label.visible_characters = _label.text.length()
		else:
			_next_line()


func _next_line() -> void:
	_index += 1
	if _index >= _lines.size():
		_finish()
		return
	var line: Dictionary = _lines[_index]
	_label.text = CareerProfile.format(line["text"])
	_label.visible_characters = 0
	_shown = 0.0
	_last_blip = 0
	_hint.visible = false
	var alert: bool = line.get("mood", "calm") == "alert"
	_alert.visible = alert
	if not alert:
		_blackout.hide()
	_show_speaker(line.get("speaker", ""))
	var sound: String = line.get("sfx", "")
	if SOUNDS.has(sound):
		_sfx.stream = SOUNDS[sound]
		_sfx.play()


func _show_speaker(npc_id: String) -> void:
	var has_speaker := not npc_id.is_empty()
	_portrait.visible = has_speaker
	_speaker.visible = has_speaker
	if has_speaker:
		_portrait.texture = NpcDatabase.portrait_of(npc_id)
		_speaker.text = CareerProfile.player_name if npc_id == PLAYER_ID else NpcDatabase.get_npc(npc_id).get("name", "")


func _finish() -> void:
	if _leaving:
		return
	_leaving = true
	get_tree().change_scene_to_file(NEXT_SCENE)
