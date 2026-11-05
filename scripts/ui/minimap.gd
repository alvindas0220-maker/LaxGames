class_name Minimap
extends Control
## Esquema de la sala: 1 píxel por celda, escalado a la baja si no cabe.

const MAX_SIZE := Vector2(64.0, 48.0)
const FLOOR_COLOR := Color8(32, 48, 58)
const WALL_COLOR := Color8(150, 170, 165)
const PLAYER_COLOR := Color8(232, 193, 90)
const PLAYER_DOT := Vector2(2.0, 2.0)

var _layer: TileMapLayer
var _player: Node2D
var _map: ImageTexture
var _origin := Vector2i.ZERO
var _map_scale := 1.0
var _cell := Vector2i.ZERO


func _ready() -> void:
	set_process(false)


func setup(layer: TileMapLayer, target: Node2D) -> void:
	_layer = layer
	_player = target
	var used := layer.get_used_rect()
	_origin = used.position
	var image := Image.create(used.size.x, used.size.y, false, Image.FORMAT_RGBA8)
	image.fill(FLOOR_COLOR)
	for cell in layer.get_used_cells():
		image.set_pixelv(cell - _origin, WALL_COLOR)
	_map = ImageTexture.create_from_image(image)
	var ratio := MAX_SIZE / Vector2(used.size)
	_map_scale = minf(1.0, minf(ratio.x, ratio.y))
	custom_minimum_size = (Vector2(used.size) * _map_scale).ceil()
	set_process(true)
	queue_redraw()


func _process(_delta: float) -> void:
	var cell := _layer.local_to_map(_layer.to_local(_player.global_position))
	if cell != _cell:
		_cell = cell
		queue_redraw()


func _draw() -> void:
	if _map == null:
		return
	draw_texture_rect(_map, Rect2(Vector2.ZERO, custom_minimum_size), false)
	var dot := (Vector2(_cell - _origin) * _map_scale).floor()
	draw_rect(Rect2(dot, PLAYER_DOT), PLAYER_COLOR)
