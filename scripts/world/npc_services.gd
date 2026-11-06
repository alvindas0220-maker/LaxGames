class_name NpcServices
extends RefCounted
## Lo que hacen los empleados que no abren tickets, según "service" en data/npcs.json.


## Devuelve true si el NPC tenía un servicio y ya respondió.
static func handle(npc_id: String, service: String) -> bool:
	match service:
		"rrhh":
			DialogueManager.speak(npc_id, "{player}, tu expediente: %s. Puesto: %s." % [GameState.warning_name(), GameState.stage_label()])
		"cafe":
			DialogueManager.speak(npc_id, _serve_coffee())
		"recepcion":
			DialogueManager.speak(npc_id, _queue_report())
		_:
			return false
	return true


static func _serve_coffee() -> String:
	if ToolBelt.free_coffee_day == WorkdayManager.day:
		return "Hoy ya te di tu café, {player}. Mañana más."
	ToolBelt.free_coffee_day = WorkdayManager.day
	ToolBelt.add_coffee(1)
	return "Toma, {player}: un café para el camino."


static func _queue_report() -> String:
	if TicketQueue.pending.is_empty():
		return "Estación central: no hay nadie en espera."
	var worst := ""
	for npc_id: String in TicketQueue.pending:
		if worst.is_empty() or TicketQueue.urgency(npc_id) > TicketQueue.urgency(worst):
			worst = npc_id
	var npc := NpcDatabase.get_npc(worst)
	return "Estación central: %d en espera. Lo más urgente: %s, de %s." % [TicketQueue.pending.size(), npc.get("name", ""), npc.get("department", "")]
