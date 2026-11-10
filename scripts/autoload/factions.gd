extends Node
## Reputación con cada grupo de la empresa: cambia premios, paciencia y trato.

signal changed

const NAMES := {
	"direccion": "Dirección", "tecnicos": "Infraestructura", "desarrollo": "Desarrollo",
	"administracion": "Administración", "servicios": "Servicios",
}
const MIN_STANDING := -100
const MAX_STANDING := 100
## A partir de aquí un grupo te aprecia o te detesta.
const FRIENDLY_FROM := 15
const HOSTILE_FROM := -15
const REWARD_BONUS := 0.15
const WAIT_BONUS := 0.2
const FRIENDLY_LINES := ["Siempre es un gusto verte.", "Aquí tienes un aliado.", "Contigo da gusto trabajar."]
const HOSTILE_LINES := ["Ah, eres tú.", "Ya me han contado de ti.", "Date prisa, tengo cosas que hacer."]

var standing := {}


func _ready() -> void:
	reset()


func change(deltas: Dictionary) -> void:
	for faction: String in deltas:
		standing[faction] = clampi(int(standing.get(faction, 0)) + int(deltas[faction]), MIN_STANDING, MAX_STANDING)
	if not deltas.is_empty():
		changed.emit()


func faction_of(npc_id: String) -> String:
	return NpcDatabase.get_npc(npc_id).get("faction", "")


func value_of(faction: String) -> int:
	return int(standing.get(faction, 0))


## 1 si el grupo del NPC te aprecia, -1 si te detesta y 0 si le das igual.
func attitude(npc_id: String) -> int:
	var value := value_of(faction_of(npc_id))
	if value >= FRIENDLY_FROM:
		return 1
	return -1 if value <= HOSTILE_FROM else 0


func reward_scale(npc_id: String) -> float:
	return 1.0 + attitude(npc_id) * REWARD_BONUS


func wait_scale(npc_id: String) -> float:
	return 1.0 + attitude(npc_id) * WAIT_BONUS


## Frase con la que te recibe según el trato; vacía si le das igual.
func greeting(npc_id: String) -> String:
	var mood := attitude(npc_id)
	if mood == 0:
		return ""
	var lines: Array = FRIENDLY_LINES if mood > 0 else HOSTILE_LINES
	return lines[absi(npc_id.hash()) % lines.size()]


func reset() -> void:
	standing.clear()
	for faction: String in NAMES:
		standing[faction] = 0
	changed.emit()


func save_state() -> Dictionary:
	return {"standing": standing}


func load_state(data: Dictionary) -> void:
	for faction: String in data["standing"]:
		standing[faction] = int(data["standing"][faction])
	changed.emit()
