extends Node
## Cola de la jornada: los NPC abren tickets solos y caducan si nadie los atiende.

signal changed
signal ticket_added(npc_id: String)
signal ticket_expired

## Último NPC cuyo ticket caducó en la cola.
var last_expired := ""

const FIRST_TICKET_DELAY := 3.0
## Margen de espera respecto al plazo del ticket.
const WAIT_SCALE := 1.2
const EXPIRE_STRESS := 15.0

## npc_id: {"ticket": TicketData, "wait": segundos restantes, "limit": segundos totales}
var pending := {}
var rng := RandomNumberGenerator.new()
var _timer := 0.0


func _ready() -> void:
	rng.randomize()


func _process(delta: float) -> void:
	if not WorkdayManager.running or WorkdayManager.in_lunch():
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = WorkdayManager.spawn_interval()
		_spawn()
	var weight := 0.0
	for npc_id: String in pending:
		weight += Incidents.queue_stress_scale(npc_id)
	GameState.add_stress(weight * WorkdayManager.queue_stress() * delta)
	for npc_id: String in pending.keys():
		pending[npc_id]["wait"] -= delta
		if pending[npc_id]["wait"] <= 0.0:
			_expire(npc_id)


func start_day() -> void:
	reset()
	_timer = FIRST_TICKET_DELAY
	if WorkdayManager.day == 1:
		add("ana")


func add(npc_id: String) -> bool:
	return _enqueue(npc_id, TicketManager.next_for(npc_id))


## Pone en cola un ticket concreto, como los que provoca un día temático.
func add_ticket(ticket_id: String) -> bool:
	for ticket: TicketData in TicketManager.catalog:
		if ticket.id == ticket_id:
			return _enqueue(ticket.requester_id, ticket)
	push_error("Ticket desconocido: %s" % ticket_id)
	return false


func _enqueue(npc_id: String, ticket: TicketData) -> bool:
	if ticket == null or pending.has(npc_id) or not StoryDirector.is_present(npc_id) or (TicketManager.active != null and TicketManager.active.requester_id == npc_id):
		return false
	var limit: float = ticket.time_limit * float(NpcDatabase.rules_of(npc_id)["time_scale"]) * WAIT_SCALE * Upgrades.patience_scale() * Factions.wait_scale(npc_id) * WorkdayManager.difficulty("wait") * Incidents.wait_scale(npc_id)
	pending[npc_id] = {"ticket": ticket, "wait": limit, "limit": limit}
	ticket_added.emit(npc_id)
	changed.emit()
	return true


## Saca de la cola el ticket de un NPC para atenderlo.
func take(npc_id: String) -> TicketData:
	if not pending.has(npc_id):
		return null
	var ticket: TicketData = pending[npc_id]["ticket"]
	pending.erase(npc_id)
	changed.emit()
	return ticket


## De 0 (recién abierto) a 1 (a punto de caducar).
func urgency(npc_id: String) -> float:
	if not pending.has(npc_id):
		return 0.0
	return 1.0 - float(pending[npc_id]["wait"]) / float(pending[npc_id]["limit"])


func reset() -> void:
	pending.clear()
	_timer = 0.0
	changed.emit()


func _spawn() -> void:
	if pending.size() >= WorkdayManager.max_pending():
		return
	var busy := TicketManager.active.requester_id if TicketManager.active != null else ""
	var free := NpcDatabase.ids().filter(func(id: String) -> bool:
		return id != busy and not pending.has(id) and StoryDirector.is_present(id) and TicketManager.next_for(id) != null)
	if not free.is_empty():
		add(free[rng.randi_range(0, free.size() - 1)])


func _expire(npc_id: String) -> void:
	pending.erase(npc_id)
	last_expired = npc_id
	ticket_expired.emit()
	TicketManager.mark_served(npc_id)
	GameState.add_stress(EXPIRE_STRESS)
	var loss := float(NpcDatabase.rules_of(npc_id)["fail_reputation"]) * WorkdayManager.reputation_pace
	GameState.add_reputation(minf(-1.0, loss))
	GameState.notice.emit("Ticket perdido: %s se cansó de esperar." % NpcDatabase.get_npc(npc_id).get("name", ""))
	changed.emit()
