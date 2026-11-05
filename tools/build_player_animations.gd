extends SceneTree
## Reconstruye las animaciones y el AnimationTree del jugador desde la hoja.
##
## Uso:  godot --headless --path . --script tools/build_player_animations.gd
## Cerrar antes el editor: reescribe scenes/player/player.tscn.

const NAMES := ["down", "right", "up", "left"]
const DIRS := [Vector2.DOWN, Vector2.RIGHT, Vector2.UP, Vector2.LEFT]
const SHEET := "res://assets/sprites/player/hero_clean.png"
const FRAME_W := 32
const FRAME_H := 32
const WALK_STEP := 0.13
const RUN_STEP := 0.08
const BLINK_AT := 2.6
const BLINK_TIME := 0.14
const XFADE := 0.0

var cols := 0


func make_anim(frames: Array, offsets: Array, length: float, loop: bool, tint: Array = []) -> Animation:
	var a := Animation.new()
	a.length = length
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var f := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(f, "Sprite2D:frame")
	a.value_track_set_update_mode(f, Animation.UPDATE_DISCRETE)
	a.track_set_interpolation_type(f, Animation.INTERPOLATION_NEAREST)
	for k: Array in frames:
		a.track_insert_key(f, k[0], k[1])
	var p := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(p, "Sprite2D:position")
	a.track_set_interpolation_type(p, Animation.INTERPOLATION_CUBIC)
	for k: Array in offsets:
		a.track_insert_key(p, k[0], k[1])
	var m := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(m, "Sprite2D:modulate")
	if tint.is_empty():
		a.track_insert_key(m, 0.0, Color.WHITE)
	for k: Array in tint:
		a.track_insert_key(m, k[0], k[1])
	return a


## Paso A, pies juntos, paso B, pies juntos. El rebote ya está dibujado.
func gait(row: int, step: float) -> Animation:
	var f: int = row * cols
	var frames := [[0.0, f + 2], [step, f + 3], [step * 2, f + 4], [step * 3, f + 5]]
	return make_anim(frames, [[0.0, Vector2.ZERO]], step * 4, true)


func make_space(prefix: String, mode: int) -> AnimationNodeBlendSpace2D:
	var s := AnimationNodeBlendSpace2D.new()
	s.blend_mode = mode
	for i in NAMES.size():
		var n := AnimationNodeAnimation.new()
		n.animation = prefix + "_" + NAMES[i]
		s.add_blend_point(n, DIRS[i], -1, NAMES[i])
	return s


func transition(condition := "", xfade := XFADE, at_end := false, auto := true) -> AnimationNodeStateMachineTransition:
	var t := AnimationNodeStateMachineTransition.new()
	t.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO if auto else AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED
	t.advance_condition = condition
	t.xfade_time = xfade
	if at_end:
		t.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
	return t


func _init() -> void:
	var tex: Texture2D = load(SHEET)
	cols = tex.get_width() / FRAME_W
	var rows := tex.get_height() / FRAME_H

	var lib := AnimationLibrary.new()
	for i in NAMES.size():
		var n: String = NAMES[i]
		var dir: Vector2 = DIRS[i]
		var f: int = i * cols
		lib.add_animation("idle_" + n, make_anim([[0.0, f], [BLINK_AT, f + 1]], [[0.0, Vector2.ZERO]], BLINK_AT + BLINK_TIME, true))
		lib.add_animation("walk_" + n, gait(i, WALK_STEP))
		lib.add_animation("run_" + n, gait(i, RUN_STEP))
		var a: int = (4 + i) * cols
		lib.add_animation("attack_" + n, make_anim(
			[[0.0, a], [0.1, a + 1], [0.16, a + 2], [0.26, a + 3]],
			[[0.0, Vector2.ZERO], [0.1, -dir * 0.5], [0.15, dir], [0.36, Vector2.ZERO]],
			0.36, false))
		lib.add_animation("hurt_" + n, make_anim(
			[[0.0, f]],
			[[0.0, Vector2.ZERO], [0.07, -dir * 2.0], [0.3, Vector2.ZERO]],
			0.3, false, [[0.0, Color(1.0, 0.4, 0.4)], [0.3, Color.WHITE]]))
	print("animaciones: ", ResourceSaver.save(lib, "res://resources/animations/player_animations.tres"))
	lib = load("res://resources/animations/player_animations.tres")

	var carry := AnimationNodeBlendSpace2D.BLEND_MODE_DISCRETE_CARRY
	var discrete := AnimationNodeBlendSpace2D.BLEND_MODE_DISCRETE
	var sm := AnimationNodeStateMachine.new()
	sm.add_node("Idle", make_space("idle", carry), Vector2(250, 100))
	sm.add_node("Walk", make_space("walk", carry), Vector2(480, 100))
	sm.add_node("Run", make_space("run", carry), Vector2(710, 100))
	sm.add_node("Attack", make_space("attack", discrete), Vector2(360, 260))
	sm.add_node("Hurt", make_space("hurt", discrete), Vector2(600, 260))
	sm.add_transition("Start", "Idle", transition("", 0.0))
	sm.add_transition("Idle", "Walk", transition("moving"))
	sm.add_transition("Idle", "Run", transition("running"))
	sm.add_transition("Walk", "Idle", transition("idle"))
	sm.add_transition("Walk", "Run", transition("running"))
	sm.add_transition("Run", "Walk", transition("moving"))
	sm.add_transition("Run", "Idle", transition("idle"))
	for from in ["Idle", "Walk", "Run"]:
		sm.add_transition(from, "Attack", transition("", 0.0, false, false))
		sm.add_transition(from, "Hurt", transition("", 0.0, false, false))
	sm.add_transition("Attack", "Hurt", transition("", 0.0, false, false))
	sm.add_transition("Attack", "Idle", transition("", XFADE, true))
	sm.add_transition("Hurt", "Idle", transition("", XFADE, true))

	var root_node: Node = (load("res://scenes/player/player.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var sprite: Sprite2D = root_node.get_node("Sprite2D")
	sprite.texture = tex
	sprite.hframes = cols
	sprite.vframes = rows
	sprite.frame = 0
	sprite.scale = Vector2.ONE
	var player: AnimationPlayer = root_node.get_node("AnimationPlayer")
	player.remove_animation_library("")
	player.add_animation_library("", lib)
	var tree: AnimationTree = root_node.get_node("AnimationTree")
	tree.tree_root = sm
	# Los fotogramas nunca se mezclan: evita poses ajenas durante los fundidos.
	tree.callback_mode_discrete = AnimationMixer.ANIMATION_CALLBACK_MODE_DISCRETE_DOMINANT
	var packed := PackedScene.new()
	packed.pack(root_node)
	print("escena: ", ResourceSaver.save(packed, "res://scenes/player/player.tscn"), " Hframes=", cols, " Vframes=", rows)
	root_node.free()
	face_down_on_start()
	quit(0)


## Godot guarda la orientación inicial en (0, 0), equidistante de todas las vistas.
func face_down_on_start() -> void:
	var path := "res://scenes/player/player.tscn"
	var text := FileAccess.get_file_as_string(path)
	text = text.replace("blend_position = Vector2(0, 0)", "blend_position = Vector2(0, 1)")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
