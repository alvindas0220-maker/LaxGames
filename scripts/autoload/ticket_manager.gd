extends Node
## Asigna tickets, controla el plazo y aplica premios y castigos según el rol
## de quien abre cada ticket. Un ticket puede encadenar varios equipos y herramientas.

signal ticket_accepted(ticket: TicketData)
signal ticket_closed
signal ticket_solved
signal ticket_lost
signal tool_error
signal repair_requested(ticket: TicketData)

const DATA_PATH := "res://data/tickets.json"
const FAULTS_PATH := "res://data/faults.json"
const WRONG_TOOL_STRESS := 3.0
const FAIL_STRESS := 15.0

var catalog: Array[TicketData] = []
## Averías técnicas: nombre, herramienta, equipos posibles y procedimiento.
var faults := {}
var active: TicketData
var time_left := 0.0
var repairs_done := 0
## Paso de la cadena del ticket activo: 0 es el equipo principal.
var stage := 0
## El minijuego está abierto: el jugador no se mueve.
var repairing := false
## Las pruebas de lógica reparan directamente, sin minijuego.
var skip_minigame := false
## Segundos que llevó resolver el último ticket.
var last_solve_seconds := 0.0
var _limit := 0.0
var _served := {}


func _ready() -> void:
	var known: Variant = JSON.parse_string(FileAccess.get_file_as_string(FAULTS_PATH))
	if known is Dictionary and known.get("faults") is Dictionary:
		faults = known["faults"]
	else:
		push_error("%s no es válido" % FAULTS_PATH)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not parsed is Dictionary or not parsed.get("tickets") is Array:
		push_error("%s no es válido" % DATA_PATH)
		return
	for entry: Dictionary in parsed["tickets"]:
		catalog.append(TicketData.from_dict(entry))


func _process(delta: float) -> void:
	if active == null:
		return
	time_left -= delta
	if time_left <= 0.0:
		_fail()


## Siguiente ticket del NPC ya disponible en esta jornada; al acabarse, repite.
func next_for(requester_id: String) -> TicketData:
	var own := catalog.filter(func(t: TicketData) -> bool:
		return t.requester_id == requester_id and t.min_day <= WorkdayManager.day)
	if own.is_empty():
		return null
	return own[int(_served.get(requester_id, 0)) % own.size()]


func accept(ticket: TicketData) -> void:
	active = ticket
	repairs_done = 0
	stage = 0
	time_left = ticket.time_limit * float(_rules(ticket)["time_scale"])
	_limit = time_left
	ticket_accepted.emit(ticket)


## Equipo que toca reparar en el paso actual del ticket activo.
func current_target() -> String:
	if active == null:
		return ""
	return active.target_id if stage == 0 else active.chain[stage - 1]["target"]


## Herramienta que exige el paso actual del ticket activo.
func current_tool() -> String:
	if active == null:
		return ""
	return active.tool if stage == 0 else active.chain[stage - 1]["tool"]


## Avería del paso actual, con su procedimiento.
func current_fault() -> Dictionary:
	if active == null:
		return {}
	return faults.get(active.fault if stage == 0 else active.chain[stage - 1]["fault"], {})


## Maniobra concreta que toca ahora dentro del procedimiento.
func current_step() -> String:
	var steps: Array = current_fault().get("steps", [])
	return steps[mini(repairs_done, steps.size() - 1)] if not steps.is_empty() else ""


## Maniobra del paso actual: tipo y parámetro, de "actions" en data/faults.json.
func current_action() -> Array:
	var actions: Array = current_fault().get("actions", [])
	return actions[mini(repairs_done, actions.size() - 1)] if not actions.is_empty() else ["timing"]


## Usa una herramienta sobre un equipo. Devuelve false si no es el equipo averiado.
func try_repair(target_id: String, tool_id: String) -> bool:
	if active == null or current_target() != target_id:
		return false
	if tool_id != current_tool():
		GameState.add_stress(WRONG_TOOL_STRESS)
		tool_error.emit()
		GameState.notice.emit("Herramienta equivocada para %s: usa %s." % [current_fault().get("name", "esta avería"), ToolBelt.tool_label(current_tool())])
		return true
	if skip_minigame:
		return repair(target_id)
	if not repairing:
		repairing = true
		repair_requested.emit(active)
	return true


## Acierto del minijuego.
func apply_hit() -> void:
	repair(current_target())


func end_repair() -> void:
	repairing = false


## Un golpe de reparación. Completarlos avanza la cadena o cierra el ticket.
func repair(target_id: String) -> bool:
	if active == null or current_target() != target_id:
		return false
	repairs_done += 1
	if repairs_done < active.repairs:
		GameState.notice.emit("Hecho. Ahora: %s (%d de %d)." % [current_step(), repairs_done, active.repairs])
		return true
	if stage >= active.chain.size():
		return resolve(target_id)
	stage += 1
	repairs_done = 0
	GameState.notice.emit("Siguiente avería: %s en %s. Usa %s." % [current_fault().get("name", ""), ToolBelt.TARGET_PLACES[current_target()], ToolBelt.tool_label(current_tool())])
	return true


## Cierra el ticket activo si target_id es su equipo actual.
func resolve(target_id: String) -> bool:
	if active == null or current_target() != target_id:
		return false
	var ticket := active
	last_solve_seconds = _limit - time_left
	var reward: float = ticket.reputation * float(_rules(ticket)["reputation_scale"]) * WorkdayManager.reputation_pace
	_close(ticket)
	GameState.notice.emit("%s (+%.1f%%)" % [ticket.done_text, reward])
	GameState.add_reputation(reward)
	ticket_solved.emit()
	return true


func priority() -> String:
	return str(_rules(active)["priority"]) if active != null else ""


func mark_served(requester_id: String) -> void:
	_served[requester_id] = int(_served.get(requester_id, 0)) + 1


## Termina la jornada sin castigo: el ticket a medias no se pierde, se aplaza.
func end_day() -> void:
	repairing = false
	if active != null:
		active = null
		ticket_closed.emit()


func reset() -> void:
	active = null
	time_left = 0.0
	repairs_done = 0
	stage = 0
	repairing = false
	_served.clear()


func _fail() -> void:
	var ticket := active
	var rules := _rules(ticket)
	_close(ticket)
	ticket_lost.emit()
	GameState.add_stress(FAIL_STRESS)
	GameState.add_reputation(minf(-1.0, float(rules["fail_reputation"]) * WorkdayManager.reputation_pace))
	var reason := "no resolviste \"%s\" a tiempo" % ticket.title
	if int(rules["warnings"]) > 0:
		GameState.add_warning(reason, int(rules["warnings"]))
	else:
		GameState.notice.emit("Ticket perdido: %s." % reason)


func _rules(ticket: TicketData) -> Dictionary:
	return NpcDatabase.rules_of(ticket.requester_id)


func _close(ticket: TicketData) -> void:
	mark_served(ticket.requester_id)
	active = null
	ticket_closed.emit()
