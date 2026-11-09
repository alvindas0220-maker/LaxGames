extends CanvasLayer
## Muestra un evento de oficina y deja elegir una respuesta. Pausa el juego.

const CURSOR := "> "

var _event := {}
var _choice := 0
var _opened_at := 0

@onready var _panel: Control = $Panel
@onready var _portrait: TextureRect = %EventPortrait
@onready var _speaker: Label = %EventSpeaker
@onready var _text: Label = %EventText
@onready var _options: Label = %EventOptions


func _ready() -> void:
	_panel.hide()
	EventDirector.event_started.connect(_on_event_started)


func _unhandled_input(event: InputEvent) -> void:
	if not _panel.visible:
		return
	var count: int = _event["options"].size()
	if event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		_select(posmod(_choice - 1, count))
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		_select(posmod(_choice + 1, count))
	elif ConfirmInput.accepted(event, _opened_at):
		_confirm()
	else:
		return
	get_viewport().set_input_as_handled()


func _on_event_started(event: Dictionary) -> void:
	_event = event
	var npc := NpcDatabase.get_npc(event["speaker"])
	_portrait.texture = NpcDatabase.portrait_of(event["speaker"])
	_speaker.text = "%s - %s" % [npc.get("name", ""), npc.get("department", "")]
	_text.text = CareerProfile.format(event["text"])
	_select(0)
	_panel.show()
	_opened_at = Time.get_ticks_msec()
	get_tree().paused = true


func _select(index: int) -> void:
	_choice = index
	var lines := PackedStringArray()
	for i in _event["options"].size():
		lines.append((CURSOR if i == index else "  ") + _event["options"][i]["label"])
	_options.text = "\n".join(lines)


func _confirm() -> void:
	var option: Dictionary = _event["options"][_choice]
	var reply := EventDirector.choose(_event, _choice)
	if option.has("next"):
		_on_event_started(StoryDirector.gossip_nodes()[option["next"]])
		return
	_panel.hide()
	get_tree().paused = false
	DialogueManager.speak(_event["speaker"], reply)
