extends Node2D
## Oficina: limita la cámara del jugador a los bordes del mapa.

@onready var _world_layer: TileMapLayer = $WorldLayer
@onready var _camera: Camera2D = $Entities/Player/Camera2D


## Letreros que cambian según lo que haya pasado en la trama.
const SIGN_CHANGES := {"ruta_honesta": ["GERENCIA", "GERENCIA (INTERVENIDA)"], "confia_sofia": ["JEFATURA DE IT", "JEFATURA DE IT - S. REYES"]}


func _ready() -> void:
	add_to_group("office")
	var life := OfficeLife.new()
	life.name = "OfficeLife"
	life.add_to_group("office_life")
	add_child(life)
	life.setup(self)
	_update_signs()
	var used := _world_layer.get_used_rect()
	var tile := Vector2i(_world_layer.tile_set.tile_size)
	_camera.limit_left = used.position.x * tile.x
	_camera.limit_top = used.position.y * tile.y
	_camera.limit_right = used.end.x * tile.x
	_camera.limit_bottom = used.end.y * tile.y
	AudioDirector.play_music()
	WorkdayManager.start_day()
	if StoryDirector.enabled:
		$EpisodeCard.present(StoryDirector.episode_today())
	if WorkdayManager.day == 1:
		GameState.notice.emit("Ana te busca en Helpdesk: habla con ella (E). Un \"!\" marca a quien espera ayuda. Tab abre tu celular.")
	else:
		var saved := " Partida guardada." if SaveGame.has_save() else ""
		GameState.notice.emit("%s. %s %s%s" % [WorkdayManager.label(), WorkdayManager.chapter_brief(), WorkdayManager.morning_note, saved])


func _update_signs() -> void:
	for flag: String in SIGN_CHANGES:
		if StoryDirector.enabled and StoryDirector.flags.has(flag):
			for label: Label in $Signs.get_children():
				if label.text == SIGN_CHANGES[flag][0]:
					label.text = SIGN_CHANGES[flag][1]
