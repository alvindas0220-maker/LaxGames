class_name OfficeLife
extends Node
## Rutina de la oficina: a la hora del almuerzo los empleados van a la cafetería,
## a media mañana y media tarde algunos se acercan a la cafetera, y después
## cada uno vuelve a su puesto.

const CAFE_FLOOR := Vector2i(0, 1)
const CHAIR := Vector2i(6, 1)
const COFFEE_CELLS := [Vector2i(3, 36), Vector2i(5, 37), Vector2i(7, 36), Vector2i(4, 38)]
## Momentos de la jornada en que dos empleados van a por café, y cuánto se quedan.
const COFFEE_BREAKS := [0.22, 0.68]
const COFFEE_PEOPLE := 2
const COFFEE_SECONDS := 20.0
## Una pausa de café que no llegó a su hora no se recupera más tarde.
const COFFEE_WINDOW := 0.05

var nav := AStarGrid2D.new()
var _world: TileMapLayer
var _seats: Array[Vector2i] = []
var _at_lunch := false
var _coffee_done := {}
var _coffee_back: Array = []
var _rng := RandomNumberGenerator.new()


func setup(room: Node) -> void:
	_world = room.get_node("WorldLayer")
	var decor: TileMapLayer = room.get_node("DecorLayer")
	var floor_layer: TileMapLayer = room.get_node("FloorLayer")
	nav.region = _world.get_used_rect()
	nav.cell_size = Vector2.ONE * 16.0
	nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	nav.update()
	for cell in _world.get_used_cells():
		nav.set_point_solid(cell)
	for terminal: Node2D in get_tree().get_nodes_in_group("terminals"):
		nav.set_point_solid(_world.local_to_map(_world.to_local(terminal.global_position)))
	for cell in decor.get_used_cells():
		if decor.get_cell_atlas_coords(cell) == CHAIR and floor_layer.get_cell_atlas_coords(cell) == CAFE_FLOOR:
			_seats.append(cell)
	_rng.randomize()


func _process(delta: float) -> void:
	if not WorkdayManager.running or not StoryDirector.enabled:
		return
	var lunch := WorkdayManager.in_lunch()
	if lunch != _at_lunch:
		_at_lunch = lunch
		if lunch:
			send_to_lunch()
		else:
			send_home()
	for i in COFFEE_BREAKS.size():
		var progress := WorkdayManager.day_progress()
		if not _coffee_done.has(i) and not lunch and progress >= COFFEE_BREAKS[i] and progress < COFFEE_BREAKS[i] + COFFEE_WINDOW:
			_coffee_done[i] = true
			coffee_break()
	for entry: Array in _coffee_back:
		entry[1] -= delta
		if entry[1] <= 0.0 and is_instance_valid(entry[0]):
			entry[0].go_home()
	_coffee_back = _coffee_back.filter(func(entry: Array) -> bool: return entry[1] > 0.0)


## Ruta entre dos puntos del mundo, como lista de centros de celda.
func route(from: Vector2, to: Vector2) -> PackedVector2Array:
	var start := _free_near(_cell(from))
	var goal := _free_near(_cell(to))
	var points := PackedVector2Array()
	for cell in nav.get_id_path(start, goal, true):
		points.append(_world.to_global(_world.map_to_local(cell)))
	return points


func send_to_lunch() -> void:
	var seats := _seats.duplicate()
	seats.shuffle()
	for npc: Npc in _commuters():
		if seats.is_empty():
			break
		npc.go_to(_world.to_global(_world.map_to_local(seats.pop_back())))


func send_home() -> void:
	for npc: Npc in _commuters():
		npc.go_home()


func coffee_break() -> void:
	var people := _commuters()
	people.shuffle()
	for i in mini(COFFEE_PEOPLE, people.size()):
		var cell: Vector2i = COFFEE_CELLS[i % COFFEE_CELLS.size()]
		people[i].go_to(_world.to_global(_world.map_to_local(cell)))
		_coffee_back.append([people[i], COFFEE_SECONDS])


## Quién sigue la rutina: los que pasean junto a su puesto, no los fijos ni los de ronda.
func _commuters() -> Array:
	return get_tree().get_nodes_in_group("npcs").filter(func(npc: Npc) -> bool: return npc.follows_routine())


func _cell(point: Vector2) -> Vector2i:
	return _world.local_to_map(_world.to_local(point))


func _free_near(cell: Vector2i) -> Vector2i:
	if nav.is_in_boundsv(cell) and not nav.is_point_solid(cell):
		return cell
	for side: Vector2i in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i(1, 1), Vector2i(-1, 1)]:
		if nav.is_in_boundsv(cell + side) and not nav.is_point_solid(cell + side):
			return cell + side
	return cell
