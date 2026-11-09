extends Node
## Amistades del protagonista: niveles, desahogos y efecto de la vida social en el estrés.

signal changed

## Puntos mínimos y nombre de cada nivel.
const TIERS := [[0, "Conocido"], [20, "Compañero"], [50, "Amigo"], [80, "Confidente"]]
const MAX_POINTS := 100
const TICKET_POINTS := 3
const CHAT_POINTS := 2
const VENT_POINTS := 3
## Alivio de desahogarse por cada nivel de amistad.
const VENT_RELIEF := 7.0
const CONFIDANT_STRESS := 0.03
## Noches de descanso extra si socializaste, o de menos tras días aislado.
const SOCIAL_REST := 10.0
const LONELY_REST := -12.0
const LONELY_DAYS := 3

var points := {}
## Charlas de hoy.
var social_today := 0
var _lonely_days := 0
var _chatted := {}


func value_of(npc_id: String) -> int:
	return int(points.get(npc_id, 0))


func tier_index(npc_id: String) -> int:
	var index := 0
	for i in TIERS.size():
		if value_of(npc_id) >= TIERS[i][0]:
			index = i
	return index


func tier_name(npc_id: String) -> String:
	return TIERS[tier_index(npc_id)][1]


func change(npc_id: String, amount: int) -> void:
	points[npc_id] = clampi(value_of(npc_id) + amount, 0, MAX_POINTS)
	changed.emit()


func mark_social() -> void:
	social_today += 1


## Charla breve de pasillo: suma una vez al día.
func chat(npc_id: String) -> void:
	if _chatted.get(npc_id, 0) != WorkdayManager.day:
		_chatted[npc_id] = WorkdayManager.day
		change(npc_id, CHAT_POINTS)
		mark_social()


func can_vent(npc_id: String) -> bool:
	return tier_index(npc_id) >= 1


func vent_relief(npc_id: String) -> float:
	return VENT_RELIEF * tier_index(npc_id)


## Ventana para desahogarse con alguien de confianza.
func vent_node(npc_id: String) -> Dictionary:
	var name_of: String = NpcDatabase.get_npc(npc_id).get("name", "").get_slice(" ", 0)
	return {
		"id": "desahogo", "type": "vida", "speaker": npc_id,
		"text": "Tienes mala cara, {player}. ¿Todo bien?",
		"options": [
			{"label": "Desahogarte con %s" % name_of, "friend": VENT_POINTS, "stress": -vent_relief(npc_id), "reply": "Para eso estamos. Respira."},
			{"label": "Solo estoy de paso", "reply": "Aquí me tienes si hace falta."},
		],
	}


## Cuántos confidentes tienes: cada uno amortigua un poco el estrés.
func stress_scale() -> float:
	var confidants := 0
	for npc_id: String in points:
		if tier_index(npc_id) == TIERS.size() - 1:
			confidants += 1
	return maxf(0.7, 1.0 - confidants * CONFIDANT_STRESS)


## Descanso de la noche según lo que socializaste, y cierre del día.
func rest_bonus() -> float:
	var bonus := SOCIAL_REST if social_today > 0 else 0.0
	_lonely_days = 0 if social_today > 0 else _lonely_days + 1
	if _lonely_days >= LONELY_DAYS:
		bonus = LONELY_REST
	social_today = 0
	return bonus


func is_lonely() -> bool:
	return _lonely_days >= LONELY_DAYS


func reset() -> void:
	points.clear()
	_chatted.clear()
	social_today = 0
	_lonely_days = 0
	changed.emit()
