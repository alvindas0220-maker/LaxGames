extends Node
## Comprueba que el jugador encaja con la sala y el HUD. No modifica nada.
##
## Uso:  godot --headless --path . res://tools/check_player_fit.tscn

const TILE := 16.0
const FEET_RADIUS := 4.0
var fails := 0


func check(label: String, ok: bool, info: Variant = "") -> void:
	if not ok:
		fails += 1
	print("%s %s %s" % ["OK  " if ok else "FAIL", label, info])


func walk_until_blocked(player: CharacterBody2D, key: int, frames: int) -> Vector2:
	player.global_position = Vector2.ZERO
	player.velocity = Vector2.ZERO
	await get_tree().physics_frame
	var e := InputEventKey.new()
	e.physical_keycode = key
	e.pressed = true
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	for i in frames:
		await get_tree().physics_frame
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	for i in 30:
		await get_tree().physics_frame
	return player.global_position.round()


func _ready() -> void:
	await get_tree().process_frame
	var room := (load("res://scenes/world/test_room.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(room)
	var player: CharacterBody2D = room.get_node("Player")
	var sprite: Sprite2D = player.get_node("Sprite2D")
	var feet: CollisionShape2D = player.get_node("CollisionShape2D")
	await get_tree().physics_frame

	var frame := Vector2(sprite.texture.get_size()) / Vector2(sprite.hframes, sprite.vframes)
	check("fotograma", frame == Vector2(32, 32) and sprite.scale == Vector2.ONE, "%s escala=%s" % [frame, sprite.scale])
	var hero := sprite.texture.get_image().get_region(Rect2i(0, 0, 32, 32)).get_used_rect()
	check("alto del heroe", hero.size.y <= TILE * 2.0, "%d px = %.1f tiles" % [hero.size.y, hero.size.y / TILE])
	var sole := hero.end.y - 16.0
	var shape_bottom := feet.position.y + FEET_RADIUS
	check("pies sobre la colision", absf(sole - shape_bottom) <= 2.0, "suela=%.0f colision=%.0f" % [sole, shape_bottom])

	var right := await walk_until_blocked(player, KEY_D, 300)
	check("muro derecho", right.x == 300.0, right)
	var top := await walk_until_blocked(player, KEY_W, 300)
	check("muro superior", top.y == -192.0 - feet.position.y + FEET_RADIUS, top)

	var hud: HUD = room.get_node("HUD")
	var hearts: HBoxContainer = hud.get_node("%Warnings")
	check("amonestaciones", hearts.get_child_count() == GameState.MAX_WARNINGS, hearts.get_child_count())
	GameState.add_warning("prueba")
	await get_tree().physics_frame
	var full := 0
	for h: TextureRect in hearts.get_children():
		if h.texture == hud.warning_on:
			full += 1
	check("amonestacion en HUD", full == 1, full)
	var face: TextureRect = hud.get_node("Root/StatusPanel/Row/PortraitFrame/Face")
	check("retrato", face.texture.atlas == sprite.texture, face.texture.region)
	print("fallos: ", fails)
	get_tree().quit(1 if fails > 0 else 0)
