class_name Npc
extends CharacterBody2D
## Personaje de la oficina: pasea cerca de su puesto y atiende al jugador.
## Sus datos salen de data/npcs.json según npc_id.

const SPEED := 28.0
const PATROL_SPEED := 40.0
## Distancia a la que un punto de ruta se da por alcanzado.
const ROUTE_REACH := 3.0
const WANDER_RADIUS := 36.0
const NEAR_PLAYER := 30.0
const STEP_TIME := 0.16
const LISTEN_TIME := 4.0
const COLS := 6
const FRAMES_PER_LOOK := 24
const WALK_COLS := [2, 3, 4, 5]
const DIRECTIONS := [Vector2.DOWN, Vector2.RIGHT, Vector2.UP, Vector2.LEFT]
## Aviso "!" sobre la cabeza de quien tiene un ticket en cola.
const MARK_TOP := -27.0
const MARK_INK := Color8(26, 20, 32)
const MARK_CALM := Color8(248, 216, 120)
const MARK_URGENT := Color8(232, 72, 60)
const URGENT_FROM := 0.66

@export var npc_id := ""
## Puntos que recorre en bucle; vacío si solo pasea junto a su puesto.
@export var route := PackedVector2Array()

var _home := Vector2.ZERO
var _look := 0
var _row := 0
var _direction := Vector2.ZERO
var _timer := 0.0
var _anim := 0.0
var _waypoint := 0
var _still := false

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_home = position
	_look = int(NpcDatabase.get_npc(npc_id).get("sprite_frame", 0))
	_still = bool(NpcDatabase.get_npc(npc_id).get("still", false))
	_timer = randf_range(0.5, 3.0)
	$Reach.interacted.connect(interact)
	add_to_group("npcs")
	TicketQueue.changed.connect(queue_redraw)
	_show_frame(0)


func _process(_delta: float) -> void:
	if TicketQueue.pending.has(npc_id):
		queue_redraw()


func _draw() -> void:
	if not TicketQueue.pending.has(npc_id):
		return
	var urgent := TicketQueue.urgency(npc_id) > URGENT_FROM or Incidents.is_critical(npc_id)
	var color := MARK_URGENT if urgent else MARK_CALM
	var top := MARK_TOP - (Time.get_ticks_msec() / 250 % 2)
	draw_rect(Rect2(-2, top, 4, 10), MARK_INK)
	draw_rect(Rect2(-1, top + 1, 2, 5), color)
	draw_rect(Rect2(-1, top + 7, 2, 2), color)


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _still:
		return
	if not route.is_empty():
		_patrol(delta)
		return
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
	var active := TicketManager.active
	if active != null and NpcDatabase.get_npc(npc_id).get("service", "").is_empty():
		DialogueManager.speak(npc_id, "Sigo esperando: %s." % active.title if active.requester_id == npc_id else "Primero termina tu ticket actual.")
		return
	var service: String = NpcDatabase.get_npc(npc_id).get("service", "")
	var ticket: TicketData = null
	if service.is_empty():
		ticket = TicketQueue.take(npc_id) if WorkdayManager.running else TicketManager.next_for(npc_id)
	if ticket != null:
		TicketManager.accept(ticket)
		DialogueManager.speak(npc_id, ticket.request)
		return
	var gossip := StoryDirector.next_gossip(npc_id)
	if not gossip.is_empty():
		StoryDirector.start_gossip(gossip)
		return
	if StoryDirector.enabled and Friends.can_vent(npc_id) and GameState.stress > 0.0 and not StoryDirector.talked_today(npc_id):
		StoryDirector.mark_talked(npc_id)
		EventDirector.event_started.emit(Friends.vent_node(npc_id))
		return
	Friends.chat(npc_id)
	if not NpcServices.handle(npc_id, service):
		DialogueManager.speak(npc_id, Factions.greeting(npc_id))


## Camina hacia el siguiente punto, primero por el eje más largo para no cortar esquinas.
func _patrol(delta: float) -> void:
	if _timer > 0.0:
		return
	var away := route[_waypoint] - position
	if away.length() <= ROUTE_REACH:
		_waypoint = (_waypoint + 1) % route.size()
		_rest(randf_range(0.5, 2.5))
		return
	var axis := Vector2(away.x, 0.0) if absf(away.x) > ROUTE_REACH else Vector2(0.0, away.y)
	_direction = axis.normalized()
	_row = _row_for(axis)
	velocity = _direction * PATROL_SPEED
	move_and_slide()
	_anim += delta
	_show_frame(WALK_COLS[int(_anim / STEP_TIME) % WALK_COLS.size()])


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
