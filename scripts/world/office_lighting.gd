extends Node2D
## Ambiente de la oficina: luz según la hora, reflejos aditivos con bandas de
## píxeles, parpadeo de LED y monitores, y vapor de la cafetera.

const GLOW := preload("res://assets/sprites/world/glow.png")
const WINDOW_PATCH := preload("res://assets/sprites/world/window_light.png")
const TILE := 16.0
const WINDOW_CELL := Vector2i(13, 0)
const MONITOR_CELL := Vector2i(13, 2)
const RACK_CELL := Vector2i(10, 2)
const COFFEE_CELL := Vector2i(10, 1)
## Color ambiente al empezar, a mediodía y al acabar la jornada.
const DAWN := Color(1.0, 0.95, 0.86)
const NOON := Color(1.0, 1.0, 1.0)
const DUSK := Color(0.8, 0.74, 0.92)
const LAMP_COLOR := Color(1.0, 0.86, 0.6, 0.16)
const SCREEN_COLOR := Color(0.4, 0.75, 1.0, 0.22)
const LED_COLOR := Color(0.3, 1.0, 0.55, 0.2)
const LED_SECONDS := 0.45
## Celdas de las lámparas de techo.
const LAMPS := [
	Vector2i(6, 6), Vector2i(18, 6), Vector2i(34, 6), Vector2i(54, 6),
	Vector2i(8, 14), Vector2i(22, 14), Vector2i(36, 14), Vector2i(50, 14), Vector2i(62, 14),
	Vector2i(8, 22), Vector2i(36, 22), Vector2i(54, 22),
	Vector2i(10, 30), Vector2i(26, 30), Vector2i(44, 30), Vector2i(58, 30),
	Vector2i(12, 40), Vector2i(30, 38), Vector2i(39, 38), Vector2i(34, 44), Vector2i(54, 40),
]

var _led_left := 0.0
var _led_on := true

@onready var _world: TileMapLayer = get_node("../WorldLayer")
@onready var _ambient: CanvasModulate = $Ambient
@onready var _screens: Node2D = $Screens
@onready var _leds: Node2D = $Leds
@onready var _lamps: Node2D = $Lamps


func _ready() -> void:
	for cell: Vector2i in LAMPS:
		_add_glow(_lamps, Vector2(cell) * TILE, 2.4, LAMP_COLOR)
	for cell in _world.get_used_cells_by_id(0, WINDOW_CELL):
		var patch := _add_glow(_lamps, Vector2(cell) * TILE + Vector2(8, 34), 1.0, Color(1, 1, 1, 0.5))
		patch.texture = WINDOW_PATCH
	for cell in _world.get_used_cells_by_id(0, MONITOR_CELL):
		_add_glow(_screens, Vector2(cell) * TILE + Vector2(8, 4), 0.5, SCREEN_COLOR)
	for cell in _world.get_used_cells_by_id(0, RACK_CELL):
		_add_glow(_leds, Vector2(cell) * TILE + Vector2(8, 8), 0.6, LED_COLOR)
	for cell in _world.get_used_cells_by_id(0, COFFEE_CELL):
		$Steam.position = Vector2(cell) * TILE + Vector2(8, 0)
		$Steam.emitting = true


func _process(delta: float) -> void:
	_ambient.color = ambient_at(WorkdayManager.day_progress())
	var now := Time.get_ticks_msec() * 0.001
	_screens.modulate.a = 0.8 + 0.2 * sin(now * 3.1)
	_lamps.modulate.a = 0.96 + 0.04 * sin(now * 13.0) * sin(now * 1.7)
	_led_left -= delta
	if _led_left <= 0.0:
		_led_left = LED_SECONDS
		_led_on = not _led_on
		_leds.modulate.a = 1.0 if _led_on else 0.45


func ambient_at(progress: float) -> Color:
	if progress < 0.5:
		return DAWN.lerp(NOON, progress * 2.0)
	return NOON.lerp(DUSK, (progress - 0.5) * 2.0)


func _add_glow(parent: Node2D, at: Vector2, size: float, color: Color) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = GLOW
	sprite.position = at
	sprite.scale = Vector2.ONE * size
	sprite.modulate = color
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var blend := CanvasItemMaterial.new()
	blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sprite.material = blend
	parent.add_child(sprite)
	return sprite
