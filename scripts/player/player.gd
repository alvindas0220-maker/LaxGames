class_name Player
extends CharacterBody2D
## Jugador con movimiento top-down en 8 direcciones.

const DIRECTION_STEP := PI / 4.0
## Por debajo de esta velocidad (px/s) el jugador se anima como parado.
const MIN_WALK_SPEED := 5.0
## A partir de esta fracción de max_speed se anima como carrera.
const RUN_ANIMATION_RATIO := 1.15
## Desempata las diagonales exactas a favor de las vistas laterales.
const FACING_BIAS := Vector2(1.05, 1.0)
const PARAM_RUN_FACING := &"parameters/Run/blend_position"
const PARAM_IS_RUNNING := &"parameters/conditions/running"
const PARAM_IDLE_FACING := &"parameters/Idle/blend_position"
const PARAM_WALK_FACING := &"parameters/Walk/blend_position"
const PARAM_ATTACK_FACING := &"parameters/Attack/blend_position"
const PARAM_PLAYBACK := &"parameters/playback"
const PARAM_HURT_FACING := &"parameters/Hurt/blend_position"
const ATTACK_STATE := &"Attack"
const HURT_STATE := &"Hurt"
const PARAM_IS_MOVING := &"parameters/conditions/moving"
const PARAM_IS_IDLE := &"parameters/conditions/idle"

## Velocidad máxima en píxeles por segundo.
@export_range(0.0, 500.0, 1.0) var max_speed := 120.0
## Velocidad en píxeles por segundo con la acción "run" pulsada.
@export_range(0.0, 500.0, 1.0) var run_speed := 190.0
## Píxeles/s² ganados al arrancar o cambiar de dirección.
@export_range(0.0, 5000.0, 10.0) var acceleration := 900.0
## Píxeles/s² perdidos al soltar el movimiento.
@export_range(0.0, 5000.0, 10.0) var friction := 1200.0

## Atacando o recibiendo daño: el jugador no controla el movimiento.
var _locked := false

@onready var _animation_tree: AnimationTree = $AnimationTree
@onready var _interactor: Interactor = $Interactor


func _ready() -> void:
	add_to_group("player")
	$Sprite2D.texture = load(CareerProfile.sheet_path())
	_animation_tree.animation_finished.connect(_on_animation_finished)
	GameState.warned.connect(_on_warning)


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("attack") and not _locked and not TicketManager.repairing and not GameState.input_locked:
		_use_tool()

	var frozen := _locked or TicketManager.repairing or GameState.input_locked
	var direction := Vector2.ZERO if frozen else _get_input_direction()

	# Sin entrada y parado no hay nada que calcular ni colisiones que resolver.
	if direction == Vector2.ZERO and velocity == Vector2.ZERO:
		return

	var rate := friction if direction == Vector2.ZERO else acceleration
	var target_speed := (run_speed if Input.is_action_pressed("run") else max_speed) * Upgrades.speed_scale()
	velocity = velocity.move_toward(direction * target_speed, rate * delta)
	move_and_slide()
	_update_animation()


## El USB sin equipo delante solo diagnostica: no hace falta el gesto de reparar.
func _use_tool() -> void:
	if not ToolBelt.use():
		return
	var applied := _interactor.use_tool()
	if not applied:
		ToolBelt.miss()
	if applied or ToolBelt.selected != ToolBelt.Tool.USB:
		_start_attack()


## Elige caminar o parado según la velocidad y orienta ambos según su dirección.
## Al detenerse no se toca la orientación, así que conserva la última.
func _update_animation() -> void:
	var speed := velocity.length()
	var moving := speed > MIN_WALK_SPEED
	var running := speed > max_speed * RUN_ANIMATION_RATIO
	_animation_tree.set(PARAM_IS_MOVING, moving and not running)
	_animation_tree.set(PARAM_IS_RUNNING, running)
	_animation_tree.set(PARAM_IS_IDLE, not moving)
	if moving:
		var facing := (velocity * FACING_BIAS).normalized()
		_animation_tree.set(PARAM_IDLE_FACING, facing)
		_animation_tree.set(PARAM_WALK_FACING, facing)
		_animation_tree.set(PARAM_RUN_FACING, facing)
		_animation_tree.set(PARAM_ATTACK_FACING, facing)
		_animation_tree.set(PARAM_HURT_FACING, facing)


## El golpe con la herramienta usa la última orientación y bloquea el movimiento.
func _start_attack() -> void:
	if _locked:
		return
	_locked = true
	_animation_tree.get(PARAM_PLAYBACK).travel(ATTACK_STATE)


## Una amonestación interrumpe cualquier otra acción, incluido un ataque.
func _on_warning() -> void:
	_locked = true
	_animation_tree.get(PARAM_PLAYBACK).travel(HURT_STATE)


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name.begins_with("attack") or anim_name.begins_with("hurt"):
		_locked = false


## Devuelve un vector unitario limitado a 8 direcciones, o cero sin entrada.
## get_vector() ya normaliza las diagonales; el ajuste limita también al stick.
func _get_input_direction() -> Vector2:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input == Vector2.ZERO:
		return Vector2.ZERO
	return Vector2.from_angle(snappedf(input.angle(), DIRECTION_STEP))
