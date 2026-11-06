class_name Minimap
extends Control
## Esquema de la oficina a media resolución: conserva las paredes al reducirlo.
## Marca al jugador, a quien espera ayuda y el equipo del ticket activo.

## Celdas del mapa por píxel del minimapa.
const CELLS_PER_PIXEL := 2
const FLOOR_COLOR := Color8(32, 48, 58)
const WALL_COLOR := Color8(150, 170, 165)
const PLAYER_COLOR := Color8(232, 193, 90)
const PLAYER_DOT := Vector2(2.0, 2.0)
const PENDING_COLOR := Color8(232, 72, 60)
const TARGET_COLOR := Color8(80, 224, 128)
const REFRESH_SECONDS := 0.25

var _layer: TileMapLayer
var _player: Node2D
var _map: ImageTexture
var _origin := Vector2i.ZERO
var _cell := Vector2i.ZERO
var _refresh := 0.0


func _ready() -> void:
	set_process(false)


func setup(layer: TileMapLayer, target: Node2D) -> void:
	_layer = layer
	_player = target
	var used := layer.get_used_rect()
	_origin = used.position
	var map_size := (used.size + Vector2i.ONE) / CELLS_PER_PIXEL
	var image := Image.create(map_size.x, map_size.y, false, Image.FORMAT_RGBA8)
	image.fill(FLOOR_COLOR)
	for cell in layer.get_used_cells():
		image.set_pixelv((cell - _origin) / CELLS_PER_PIXEL, WALL_COLOR)
	_map = ImageTexture.create_from_image(image)
	custom_minimum_size = Vector2(map_size)
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_cell = _cell_of(_player)
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = REFRESH_SECONDS
		queue_redraw()


func _draw() -> void:
	if _map == null:
		return
	draw_texture_rect(_map, Rect2(Vector2.ZERO, custom_minimum_size), false)
	for npc: Npc in get_tree().get_nodes_in_group("npcs"):
		if TicketQueue.pending.has(npc.npc_id):
			_draw_dot(_cell_of(npc), PENDING_COLOR)
	for terminal: Terminal in get_tree().get_nodes_in_group("terminals"):
		if terminal.target_id == TicketManager.current_target():
			_draw_dot(_cell_of(terminal), TARGET_COLOR)
	_draw_dot(_cell, PLAYER_COLOR)


func _cell_of(node: Node2D) -> Vector2i:
	return _layer.local_to_map(_layer.to_local(node.global_position))


func _draw_dot(cell: Vector2i, color: Color) -> void:
	draw_rect(Rect2(Vector2((cell - _origin) / CELLS_PER_PIXEL), PLAYER_DOT), color)
