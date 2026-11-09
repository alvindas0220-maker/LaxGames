class_name ClueSpot
extends Interactable
## Secreto escondido en la oficina: un destello discreto delata lo que aún no se examinó.

const GLINT := Color8(255, 244, 200)

@export var clue_id := ""
@export var empty_text := "Nada que llame la atención."


func _ready() -> void:
	StoryDirector.story_changed.connect(queue_redraw)


func _process(_delta: float) -> void:
	if _shows_glint():
		queue_redraw()


func interact() -> void:
	if _shows_glint():
		StoryDirector.discover(clue_id)
	else:
		GameState.notice.emit(empty_text)


func _shows_glint() -> bool:
	return not StoryDirector.has_clue(clue_id) and StoryDirector.can_find(clue_id)


func _draw() -> void:
	if not _shows_glint() or Time.get_ticks_msec() / 500 % 4 != 0:
		return
	draw_rect(Rect2(-1, -1, 3, 1), GLINT)
	draw_rect(Rect2(0, -2, 1, 3), GLINT)
