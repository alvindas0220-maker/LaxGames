class_name Npc
extends CharacterBody2D
## Personaje de la oficina: pasea cerca de su puesto y atiende al jugador.
## Sus datos salen de data/npcs.json según npc_id.

const SPEED := 28.0
const WANDER_RADIUS := 36.0
const NEAR_PLAYER := 30.0
const STEP_TIME := 0.16
const LISTEN_TIME := 4.0
const COLS := 6
const FRAMES_PER_LOOK := 24
const WALK_COLS := [2, 3, 4, 5]
const DIRECTIONS := [Vector2.DOWN, Vector2.RIGHT, Vector2.UP, Vector2.LEFT]

@export var npc_id := ""

var _home := Vector2.ZERO
var _look := 0
var _row := 0
var _direction := Vector2.ZERO
var _timer := 0.0
var _anim := 0.0

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_home = position
	_look = int(NpcDatabase.get_npc(npc_id).get("sprite_frame", 0))
	_timer = randf_range(0.5, 3.0)
	$Reach.interacted.connect(interact)
	_show_frame(0)


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _direction == Vector2.ZERO:
		if _timer <= 0.0:
			_start_walking()
		return
	velocity = _direction * SPEED
	move_and_slide()
	_anim += delta
	_show_frame(WALK_COLS[int(_anim / STEP_TIME) % WALK_COLS.size()])
	if _timer <= 0.0 or get_slide_collision_count() > 0 or position.distance_to(_home) > WANDER_RADIUS:
		_rest(randf_range(1.5, 5.0))


func interact() -> void:
	_rest(LISTEN_TIME)
	_face_player()
	var npc := NpcDatabase.get_npc(npc_id)
	if npc.get("service", "") == "rrhh":
		DialogueManager.speak(npc_id, "Tu expediente: %s. Puesto: %s." % [GameState.warning_name(), GameState.stage_title()])
		return
	var active := TicketManager.active
	if active != null:
		DialogueManager.speak(npc_id, "Sigo esperando: %s." % active.title if active.requester_id == npc_id else "Primero termina tu ticket actual.")
		return
	var ticket := TicketManager.next_for(npc_id)
	if ticket == null:
		DialogueManager.speak(npc_id)
		return
	TicketManager.accept(ticket)
	DialogueManager.speak(npc_id, ticket.request)


func _start_walking() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and player.global_position.distance_to(global_position) < NEAR_PLAYER:
		_rest(1.0)
		return
	var away := _home - position
	if away.length() > WANDER_RADIUS * 0.6:
		_row = _row_for(away)
	else:
		_row = randi() % DIRECTIONS.size()
	_direction = DIRECTIONS[_row]
	_timer = randf_range(0.4, 1.2)
	_anim = 0.0


func _rest(seconds: float) -> void:
	_direction = Vector2.ZERO
	velocity = Vector2.ZERO
	_timer = seconds
	_show_frame(0)


func _face_player() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		_row = _row_for(player.global_position - global_position)
		_show_frame(0)


func _row_for(offset: Vector2) -> int:
	if absf(offset.x) > absf(offset.y):
		return 1 if offset.x > 0.0 else 3
	return 0 if offset.y > 0.0 else 2


func _show_frame(col: int) -> void:
	_sprite.frame = _look * FRAMES_PER_LOOK + _row * COLS + col
