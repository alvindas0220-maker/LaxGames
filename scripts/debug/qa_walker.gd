class_name QaWalker
extends RefCounted
## Lleva al personaje a un destino con pulsaciones reales, siguiendo una ruta A*.

const MOVES := ["move_left", "move_right", "move_up", "move_down"]
const TILE := 16.0
## Los pies del personaje quedan por debajo de su origen.
const FEET := Vector2(0, 9)
const WAYPOINT_REACH := 4.0
const REPATH_SECONDS := 1.0
const STUCK_SECONDS := 1.5
const STUCK_MOVE := 2.0
const APPROACH := [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]

var stuck_count := 0
var _grid := AStarGrid2D.new()
var _layer: TileMapLayer
var _player: Node2D
var _path: Array[Vector2i] = []
var _repath := 0.0
var _stuck := 0.0
var _last := Vector2.ZERO
var _people: Array[Vector2i] = []


func setup(room: Node, player: Node2D) -> void:
	_layer = room.get_node("WorldLayer")
	_player = player
	_grid.region = _layer.get_used_rect()
	_grid.cell_size = Vector2.ONE * TILE
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_grid.update()
	for cell in _layer.get_used_cells():
		_grid.set_point_solid(cell)
	for terminal: Node2D in room.get_tree().get_nodes_in_group("terminals"):
		_grid.set_point_solid(_cell_of(terminal.global_position))


## Da un paso hacia el destino. Devuelve false si lleva demasiado sin moverse.
func walk_to(goal: Vector2, delta: float) -> bool:
	_repath -= delta
	if _path.is_empty() or _repath <= 0.0:
		_repath = REPATH_SECONDS
		_path = _route(_cell_of(_feet()), _cell_of(goal))
	if _path.is_empty():
		_steer(goal - _feet())
		return _track_movement(delta)
	var next := _center(_path[0])
	if _feet().distance_to(next) <= WAYPOINT_REACH:
		_path.pop_front()
		return true
	_steer(next - _feet())
	return _track_movement(delta)


func stop() -> void:
	for action: String in MOVES:
		Input.action_release(action)


func reset_tracking() -> void:
	_stuck = 0.0
	_path.clear()
	_last = _player.global_position


## Los NPC se paran al acercarse el jugador: la ruta los rodea como haría una persona.
func _mark_people(goal_cell: Vector2i) -> void:
	for cell in _people:
		_grid.set_point_solid(cell, false)
	_people.clear()
	for npc: Node2D in _player.get_tree().get_nodes_in_group("npcs"):
		var cell := _cell_of(npc.global_position + FEET)
		if cell != goal_cell and _grid.is_in_boundsv(cell) and not _grid.is_point_solid(cell):
			_grid.set_point_solid(cell)
			_people.append(cell)


func _route(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	_mark_people(to)
	var start := _free_near(from)
	var path := _grid.get_id_path(start, _free_near(to), true)
	var route: Array[Vector2i] = []
	route.assign(path.slice(1))
	return route


## Celda libre más cercana, para puntos que caen dentro de un mueble.
func _free_near(cell: Vector2i) -> Vector2i:
	if _grid.is_in_boundsv(cell) and not _grid.is_point_solid(cell):
		return cell
	# Los pies quedan bajo el origen: abajo y a los lados el equipo queda al alcance.
	for side: Vector2i in APPROACH:
		var beside := cell + side
		if _grid.is_in_boundsv(beside) and not _grid.is_point_solid(beside):
			return beside
	for radius in range(1, 5):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				var near := cell + Vector2i(dx, dy)
				if _grid.is_in_boundsv(near) and not _grid.is_point_solid(near):
					return near
	return cell


func _steer(direction: Vector2) -> void:
	stop()
	if absf(direction.x) > 1.0:
		Input.action_press("move_right" if direction.x > 0.0 else "move_left")
	if absf(direction.y) > 1.0:
		Input.action_press("move_down" if direction.y > 0.0 else "move_up")


func _track_movement(delta: float) -> bool:
	if _player.global_position.distance_to(_last) >= STUCK_MOVE:
		_last = _player.global_position
		_stuck = 0.0
		return true
	_stuck += delta
	if _stuck < STUCK_SECONDS:
		return true
	_stuck = 0.0
	stuck_count += 1
	_path.clear()
	return false


func _feet() -> Vector2:
	return _player.global_position + FEET


func _cell_of(point: Vector2) -> Vector2i:
	return _layer.local_to_map(_layer.to_local(point))


func _center(cell: Vector2i) -> Vector2:
	return _layer.to_global(_layer.map_to_local(cell))
