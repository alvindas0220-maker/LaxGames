extends Control
## Epílogo: ilustración del final, destino de cada compañero según tu trato con
## él y cierre. Al acabar empieza una partida nueva en el menú principal.

const FATE_LIMIT := 6

var slides: Array = []
var _index := -1
var _opened_at := 0
var _leaving := false

@onready var _image: TextureRect = %EpilogueImage
@onready var _portrait: TextureRect = %EpiloguePortrait
@onready var _title: Label = %EpilogueTitle
@onready var _text: Label = %EpilogueText


func _ready() -> void:
	get_tree().paused = false
	AudioDirector.play_music()
	AudioDirector.play("stinger")
	slides = build_slides()
	next_slide()


func _unhandled_input(event: InputEvent) -> void:
	if _leaving or not ConfirmInput.accepted(event, _opened_at):
		return
	get_viewport().set_input_as_handled()
	next_slide()


## Diapositivas del final elegido y de los compañeros con los que tuviste trato.
func build_slides() -> Array:
	var data := StoryDirector.epilogue_data()
	var ending: Dictionary = data.get(StoryDirector.ending, data.get("propio", {}))
	var result: Array = [{"image": ending.get("image", ""), "title": ending.get("title", "Fin"), "text": CareerProfile.format(ending.get("text", ""))}]
	var used := {}
	for fate: Dictionary in data.get("fates", []):
		if used.has(fate["npc"]) or result.size() > FATE_LIMIT:
			continue
		if StoryDirector.is_available(fate.get("when", {})):
			used[fate["npc"]] = true
			result.append({"image": ending.get("image", ""), "portrait": fate["npc"], "title": NpcDatabase.get_npc(fate["npc"]).get("name", ""), "text": CareerProfile.format(fate["text"])})
	result.append({"image": ending.get("image", ""), "title": "FIN", "text": "Gracias por jugar a LaxCorp, %s.\n\nPulsa Enter para volver al menú." % CareerProfile.player_name})
	return result


func next_slide() -> void:
	if _leaving:
		return
	_index += 1
	if _index >= slides.size():
		_leaving = true
		WorkdayManager.new_game()
		get_tree().change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
		return
	var slide: Dictionary = slides[_index]
	if not slide["image"].is_empty():
		_image.texture = load("res://assets/sprites/scenes/%s.png" % slide["image"])
	_portrait.visible = slide.has("portrait")
	if slide.has("portrait"):
		_portrait.texture = NpcDatabase.portrait_of(slide["portrait"])
	_title.text = slide["title"]
	_text.text = slide["text"]
	_opened_at = Time.get_ticks_msec()
