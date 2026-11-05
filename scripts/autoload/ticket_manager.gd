extends Node
## Asigna tickets, controla el plazo y aplica premios y castigos según el rol
## de quien abre cada ticket.

signal ticket_accepted(ticket: TicketData)
signal ticket_closed

const DATA_PATH := "res://data/tickets.json"

var catalog: Array[TicketData] = []
var active: TicketData
var time_left := 0.0
var repairs_done := 0
var _served := {}


func _ready() -> void:
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
	time_left = ticket.time_limit * float(_rules(ticket)["time_scale"])
	ticket_accepted.emit(ticket)


## Un golpe de kit sobre un equipo. Cierra el ticket al completar sus reparaciones.
func repair(target_id: String) -> bool:
	if active == null or active.target_id != target_id:
		return false
	repairs_done += 1
	if repairs_done >= active.repairs:
		return resolve(target_id)
	GameState.notice.emit("Reparando: %d de %d." % [repairs_done, active.repairs])
	return true


## Cierra el ticket activo si target_id es su equipo.
func resolve(target_id: String) -> bool:
	if active == null or active.target_id != target_id:
		return false
	var ticket := active
	var reward := maxi(1, roundi(ticket.reputation * float(_rules(ticket)["reputation_scale"]) * WorkdayManager.reputation_pace))
	_close(ticket)
	GameState.notice.emit("%s (+%d%%)" % [ticket.done_text, reward])
	GameState.add_reputation(reward)
	return true


func priority() -> String:
	return str(_rules(active)["priority"]) if active != null else ""


func reset() -> void:
	active = null
	time_left = 0.0
	repairs_done = 0
	_served.clear()


func _fail() -> void:
	var ticket := active
	var rules := _rules(ticket)
	_close(ticket)
	GameState.add_reputation(mini(-1, roundi(float(rules["fail_reputation"]) * WorkdayManager.reputation_pace)))
	var reason := "no resolviste \"%s\" a tiempo" % ticket.title
	if int(rules["warnings"]) > 0:
		GameState.add_warning(reason, int(rules["warnings"]))
	else:
		GameState.notice.emit("Ticket perdido: %s." % reason)


func _rules(ticket: TicketData) -> Dictionary:
	return NpcDatabase.rules_of(ticket.requester_id)


func _close(ticket: TicketData) -> void:
	_served[ticket.requester_id] = int(_served.get(ticket.requester_id, 0)) + 1
	active = null
	ticket_closed.emit()
