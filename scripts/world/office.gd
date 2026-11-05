extends Node2D
## Oficina: limita la cámara del jugador a los bordes del mapa.

@onready var _world_layer: TileMapLayer = $WorldLayer
@onready var _camera: Camera2D = $Entities/Player/Camera2D


func _ready() -> void:
	var used := _world_layer.get_used_rect()
	var tile := Vector2i(_world_layer.tile_set.tile_size)
	_camera.limit_left = used.position.x * tile.x
	_camera.limit_top = used.position.y * tile.y
	_camera.limit_right = used.end.x * tile.x
	_camera.limit_bottom = used.end.y * tile.y
	if WorkdayManager.day == 1 and GameState.reputation == 0:
		GameState.notice.emit("Ana te busca en la oficina: habla con ella (E) para tu primer ticket.")
	else:
		GameState.notice.emit("%s. %s" % [WorkdayManager.label(), WorkdayManager.chapter_brief()])
