class_name LunchTable
extends Interactable
## Mesa del comedor: a la hora del almuerzo se elige con quién comer.

const COMPANIONS := 3
const LUNCH_RELIEF := 15.0
const LUNCH_FRIEND := 8


func interact() -> void:
	if not WorkdayManager.in_lunch():
		GameState.notice.emit("El comedor abre de 13:00 a 13:45.")
	elif WorkdayManager.lunch_taken:
		GameState.notice.emit("Ya almorzaste hoy.")
	else:
		WorkdayManager.lunch_taken = true
		EventDirector.event_started.emit(lunch_node())


## Ventana con tres compañeros al azar; comer con alguien fortalece esa amistad.
func lunch_node() -> Dictionary:
	var special := DayEvents.lunch_override()
	if not special.is_empty():
		return special
	var mates: Array = StoryDirector.lunch_mates().duplicate()
	mates.shuffle()
	var options: Array = []
	for npc_id: String in mates.slice(0, COMPANIONS):
		options.append({
			"label": "Comer con %s" % NpcDatabase.get_npc(npc_id).get("name", "").get_slice(" ", 0),
			"friend_id": npc_id, "friend": LUNCH_FRIEND, "stress": -LUNCH_RELIEF * DayEvents.mod("lunch", 1.0),
			"reply": "Buen rato. Hacía falta olvidarse de los tickets.",
		})
	options.append({"label": "Comer a solas", "stress": -LUNCH_RELIEF / 2.0, "reply": "Un rato de silencio tampoco viene mal."})
	return {"id": "almuerzo", "type": "vida", "speaker": "carla", "text": "Hoy hay sopa, {player}. ¿Con quién te sientas?", "options": options}
