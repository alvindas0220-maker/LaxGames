class_name QaSolver
extends RefCounted
## Resuelve cada maniobra de RepairBar enviando las mismas teclas que un jugador.

const PRESS_SECONDS := 0.07
const HOLD_GRACE := 6
const FINGER_MOVES := {Vector2i.LEFT: "move_left", Vector2i.RIGHT: "move_right", Vector2i.UP: "move_up", Vector2i.DOWN: "move_down"}

var _wait := 0.0
var _holding := false
var _hold_frames := 0


func reset() -> void:
	if _holding:
		send("attack", false)
	_holding = false
	_wait = 0.0


## Un paso de resolución; se llama cada fotograma con el minijuego abierto.
func solve(bar: RepairBar, delta: float) -> void:
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = PRESS_SECONDS
	var action := bar._action
	if action is CipherAction or action is TypingAction:
		type_char(action.command[action.typed])
	elif action is ScrewsAction:
		tap(ScrewsAction.ACTIONS[action.done % ScrewsAction.ACTIONS.size()])
	elif action is PullAction:
		_hold_if(action.tension < 0.6)
	elif action is WiresAction:
		tap("slot_%d" % (action.order[action.done] + 1))
	elif action is PortsAction:
		_cursor_to(action.cursor, action.dead)
	elif action is RaidAction:
		_cursor_to(action.cursor, action.failed[0])
	elif action is FingerprintAction:
		_solve_fingerprint(action)
	elif action is ThermostatAction:
		_solve_thermostat(action)
	elif action is CameraAction:
		_solve_camera(action)
	elif action is BeepAction:
		if not action.showing:
			tap(BeepAction.ACTIONS[action.code[action.entered]])
	else:
		_solve_builtin(bar)


func tap(action: String) -> void:
	send(action, true)
	send(action, false)


func send(action: String, down: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = down
	Input.parse_input_event(event)


func type_char(character: String) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.unicode = character.unicode_at(0)
	Input.parse_input_event(event)
	var release := InputEventKey.new()
	release.pressed = false
	Input.parse_input_event(release)


func _solve_builtin(bar: RepairBar) -> void:
	match bar._kind:
		"timing":
			_wait = 0.0
			if bar._in_zone():
				tap("attack")
				_wait = PRESS_SECONDS
		"hold":
			_wait = 0.0
			if _holding and not bar._holding and _waited_hold():
				_holding = false
				send("attack", false)
			elif not bar._holding and not _holding:
				_hold_if(true)
			elif bar._holding and bar._position >= (bar._zone.x + bar._zone.y) / 2.0:
				_hold_if(false)
				_wait = PRESS_SECONDS
		"pairs":
			tap(RepairBar.PAIR_ACTIONS[bar._pair])


## Da margen a que la barra reciba la pulsación antes de darla por perdida.
func _waited_hold() -> bool:
	_hold_frames += 1
	if _hold_frames < HOLD_GRACE:
		return false
	_hold_frames = 0
	return true


func _hold_if(wanted: bool) -> void:
	if wanted != _holding:
		_holding = wanted
		send("attack", wanted)


func _cursor_to(cursor: int, goal: int) -> void:
	if cursor == goal:
		tap("attack")
	else:
		tap("move_right" if goal > cursor else "move_left")


func _solve_fingerprint(action: FingerprintAction) -> void:
	for y in FingerprintAction.ROWS:
		for x in FingerprintAction.COLS:
			var cell := Vector2i(x, y)
			if action.template.has(cell) != action.current.has(cell):
				if cell == action.cursor:
					tap("attack")
				elif cell.x != action.cursor.x:
					tap("move_right" if cell.x > action.cursor.x else "move_left")
				else:
					tap("move_down" if cell.y > action.cursor.y else "move_up")
				return


func _solve_thermostat(action: ThermostatAction) -> void:
	var middle := (ThermostatAction.LOW + ThermostatAction.HIGH) / 2.0
	if absf(action.temperature - middle) > ThermostatAction.STEP / 2.0:
		tap("move_right" if action.temperature < middle else "move_left")


func _solve_camera(action: CameraAction) -> void:
	var offset := action.mark - action.aim
	if offset.length() <= CameraAction.TOLERANCE:
		tap("attack")
	elif absf(offset.x) >= absf(offset.y):
		tap("move_right" if offset.x > 0.0 else "move_left")
	else:
		tap("move_down" if offset.y > 0.0 else "move_up")
