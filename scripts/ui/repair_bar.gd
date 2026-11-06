class_name RepairBar
extends CanvasLayer

signal gig_finished(completed: bool, misses: int)
## Maniobras de reparación: cada paso de una avería tiene la suya, según
## "actions" en data/faults.json. Timing, hold y pairs viven aquí; el resto son
## objetos RepairAction en scripts/ui/actions/.

const MISS_STRESS := 4.0
const CURSOR_SPEED := 1.1
## Hasta cuánto acelera el cursor con el estrés al máximo.
const STRESS_SPEED := 0.8
const ZONE_WIDE := 0.26
const ZONE_NARROW := 0.14
const FILL_SPEED := 0.75
const PAIR_SECONDS := 2.5
## Evita que la pulsación que cierra la barra se use también en el mundo.
const RELEASE_DELAY := 0.12
const PAIR_ACTIONS := ["move_up", "move_right", "move_down", "move_left"]
const PAIR_NAMES := ["ARRIBA", "DERECHA", "ABAJO", "IZQUIERDA"]
const PAIR_COLORS := [Color8(44, 106, 208), Color8(232, 176, 72), Color8(80, 224, 128), Color8(232, 72, 60)]
const HINTS := {
	"kit": "Kit: pulsa Espacio en verde",
	"usb": "USB: mantén Espacio y suelta en verde",
	"tester": "Tester: pulsa la dirección del par",
}
## Maniobra por defecto de cada herramienta, para los trabajos extra.
const TOOL_ACTIONS := {"kit": ["timing"], "usb": ["hold"], "tester": ["pairs"]}
const PROPS := preload("res://assets/sprites/world/office_props.png")
const PROP_SIZE := 16.0
const COLOR_BACK := Color8(26, 20, 32)
const COLOR_TRACK := Color8(60, 70, 86)
const COLOR_ZONE := Color8(80, 224, 128)
const COLOR_CURSOR := Color8(248, 216, 120)

var _tool := ""
## Maniobra del paso en curso.
var _kind := ""
var _action: RepairAction
var _position := 0.0
var _direction := 1.0
var _zone := Vector2.ZERO
var _holding := false
var _pair := 0
var _pair_left := 0.0
var _stage := 0
## Rondas que faltan de un trabajo extra; 0 si es un ticket normal.
var _gig_left := 0
var _gig_total := 0
var _gig_misses := 0
var _gig_title := ""

@onready var _panel: Control = $Panel
@onready var _title: Label = %RepairTitle
@onready var _hint: Label = %RepairHint
@onready var _step: Label = %RepairStep
@onready var _gauge: Control = %RepairGauge
@onready var _icon: TextureRect = %RepairIcon


func _ready() -> void:
	_panel.hide()
	set_process(false)
	_gauge.draw.connect(_draw_gauge)
	TicketManager.repair_requested.connect(_open)
	TicketManager.ticket_closed.connect(_close)


func _process(delta: float) -> void:
	if _action != null:
		_action.tick(delta)
		if _action != null:
			_hint.text = _action.hint
		_gauge.queue_redraw()
		return
	match _kind:
		"timing":
			_position += _direction * CURSOR_SPEED * _speed_scale() * delta
			if _position <= 0.0 or _position >= 1.0:
				_position = clampf(_position, 0.0, 1.0)
				_direction = -_direction
		"hold":
			if _holding:
				_position += FILL_SPEED * _speed_scale() * delta
				if _position >= 1.0:
					_holding = false
					_miss()
		"pairs":
			_pair_left -= delta
			if _pair_left <= 0.0:
				_miss()
	_gauge.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not _panel.visible:
		return
	if event.is_action_pressed("ui_cancel") or (event.is_action_pressed("interact") and not _action is TypingAction):
		_close()
	elif _action != null:
		_action.handle(event)
	elif _kind == "pairs":
		_input_tester(event)
	elif _kind == "hold":
		_input_usb(event)
	elif event.is_action_pressed("attack"):
		_judge(_in_zone())
	else:
		return
	get_viewport().set_input_as_handled()


func _input_usb(event: InputEvent) -> void:
	if event.is_action_pressed("attack"):
		_holding = true
		_position = 0.0
	elif event.is_action_released("attack") and _holding:
		_holding = false
		_judge(_in_zone())


func _input_tester(event: InputEvent) -> void:
	for i in PAIR_ACTIONS.size():
		if event.is_action_pressed(PAIR_ACTIONS[i]):
			_judge(i == _pair)
			return


func _open(ticket: TicketData) -> void:
	_tool = TicketManager.current_tool()
	_stage = TicketManager.stage
	_title.text = TicketManager.current_fault().get("name", ticket.title)
	_show_equipment()
	_next_round()
	_panel.show()
	set_process(true)


## Trabajo fuera de horario: mismo minijuego, sin ticket, con el juego en pausa.
func start_gig(title: String, tool_id: String, rounds: int) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_gig_left = rounds
	_gig_total = rounds
	_gig_misses = 0
	_gig_title = title
	_tool = tool_id
	_title.text = title
	_icon.hide()
	_next_round()
	_panel.show()
	set_process(true)


func _close() -> void:
	if not _panel.visible:
		return
	_panel.hide()
	set_process(false)
	if _gig_left > 0:
		_finish_gig(false)
		return
	get_tree().create_timer(RELEASE_DELAY).timeout.connect(TicketManager.end_repair)


func _finish_gig(completed: bool) -> void:
	_gig_left = 0
	_gig_total = 0
	process_mode = Node.PROCESS_MODE_INHERIT
	gig_finished.emit(completed, _gig_misses)


func _judge(hit: bool) -> void:
	if not hit:
		_miss()
		return
	AudioDirector.play("hit")
	DayStats.hits += 1
	if _gig_left > 0:
		_gig_left -= 1
		if _gig_left == 0:
			_panel.hide()
			set_process(false)
			_finish_gig(true)
		else:
			_next_round()
		return
	var ticket := TicketManager.active
	TicketManager.apply_hit()
	if TicketManager.active != ticket or TicketManager.stage != _stage:
		_close()
	else:
		_next_round()


func _miss() -> void:
	DayStats.misses += 1
	if _gig_left > 0:
		_gig_misses += 1
	else:
		GameState.add_stress(MISS_STRESS)
		GameState.notice.emit("Fallo de maniobra: el equipo sigue igual.")
	_next_round()


## Muestra el equipo real sobre el que se trabaja.
func _show_equipment() -> void:
	_icon.hide()
	for terminal: Terminal in get_tree().get_nodes_in_group("terminals"):
		if terminal.target_id == TicketManager.current_target():
			var frame := AtlasTexture.new()
			frame.atlas = PROPS
			frame.region = Rect2(terminal.look * PROP_SIZE, 0, PROP_SIZE, PROP_SIZE)
			_icon.texture = frame
			_icon.show()


func _start_action() -> void:
	var step: Array = TOOL_ACTIONS[_tool] if _gig_total > 0 else TicketManager.current_action()
	_kind = step[0]
	_action = _make_action(_kind)
	if _action != null:
		_action.finished.connect(_judge)
		_action.begin(step[1] if step.size() > 1 else null, _speed_scale())
		_hint.text = _action.hint
	else:
		_hint.text = HINTS[_tool]


func _make_action(kind: String) -> RepairAction:
	match kind:
		"type":
			return TypingAction.new()
		"screws":
			return ScrewsAction.new()
		"pull":
			return PullAction.new()
		"wires":
			return WiresAction.new()
		"ports":
			return PortsAction.new()
	return null


func _next_round() -> void:
	var width := lerpf(ZONE_WIDE, ZONE_NARROW, GameState.stress / GameState.MAX_STRESS) * Upgrades.zone_scale()
	var start := randf_range(0.25, 0.95 - width)
	_zone = Vector2(start, start + width)
	_position = 0.0
	_direction = 1.0
	_holding = false
	_pair = randi() % PAIR_ACTIONS.size()
	_pair_left = PAIR_SECONDS / _speed_scale()
	_start_action()
	if _gig_total > 0:
		_step.text = "Trabajo extra (%d/%d)" % [_gig_total - _gig_left + 1, _gig_total]
	else:
		_step.text = "%s (%d/%d)" % [TicketManager.current_step(), TicketManager.repairs_done + 1, TicketManager.active.repairs]
	if _kind == "pairs":
		_hint.text = "Tester: pulsa %s" % PAIR_NAMES[_pair]
	_gauge.queue_redraw()


func _in_zone() -> bool:
	return _position >= _zone.x and _position <= _zone.y


func _speed_scale() -> float:
	return 1.0 + GameState.stress / GameState.MAX_STRESS * STRESS_SPEED


func _draw_gauge() -> void:
	var size := _gauge.size
	if _action != null:
		_action.paint(_gauge, size)
		return
	_gauge.draw_rect(Rect2(Vector2.ZERO, size), COLOR_BACK)
	if _kind == "pairs":
		_draw_pairs(size)
	else:
		_draw_track(size)


func _draw_track(size: Vector2) -> void:
	var track := Rect2(2, 4, size.x - 4, size.y - 8)
	_gauge.draw_rect(track, COLOR_TRACK)
	var zone_x := track.position.x + floorf(_zone.x * track.size.x)
	var zone_w := floorf((_zone.y - _zone.x) * track.size.x)
	_gauge.draw_rect(Rect2(zone_x, track.position.y, zone_w, track.size.y), COLOR_ZONE)
	var cursor_x := track.position.x + floorf(_position * track.size.x)
	if _kind == "hold":
		_gauge.draw_rect(Rect2(track.position.x, size.y - 3, cursor_x - track.position.x, 2), COLOR_CURSOR)
	_gauge.draw_rect(Rect2(cursor_x - 1, 1, 3, size.y - 2), COLOR_CURSOR)


func _draw_pairs(size: Vector2) -> void:
	var center := (size / 2.0).floor()
	var offsets := [Vector2(0, -6), Vector2(8, 0), Vector2(0, 6), Vector2(-8, 0)]
	for i in offsets.size():
		var color: Color = PAIR_COLORS[i] if i == _pair else COLOR_TRACK
		_gauge.draw_rect(Rect2(center + offsets[i] - Vector2(3, 2), Vector2(6, 4)), color)
	var left := floorf(_pair_left / (PAIR_SECONDS / _speed_scale()) * (size.x - 4))
	_gauge.draw_rect(Rect2(2, size.y - 2, left, 1), COLOR_CURSOR)
