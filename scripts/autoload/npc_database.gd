extends Node
## Carga y valida los NPC de data/npcs.json y las reglas de data/roles.json.

const DATA_PATH := "res://data/npcs.json"
const ROLES_PATH := "res://data/roles.json"
const GENERIC_PORTRAIT := "res://assets/sprites/npc/portraits/generic.png"
const REQUIRED_FIELDS := ["id", "name", "department", "role", "sprite_frame", "dialogue"]

var _npcs := {}
var _roles := {}


func _ready() -> void:
	var roles: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROLES_PATH))
	if roles is Dictionary:
		_roles = roles
	else:
		push_error("%s no es válido" % ROLES_PATH)
	load_from(DATA_PATH)


## Sustituye los datos cargados. Devuelve cuántos NPC válidos hay.
func load_from(path: String) -> int:
	_npcs.clear()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not parsed.get("npcs") is Array:
		push_error("%s no tiene una lista \"npcs\"" % path)
		return 0
	for entry: Variant in parsed["npcs"]:
		if _is_valid(entry):
			_npcs[entry["id"]] = entry
	return _npcs.size()


func has_npc(npc_id: String) -> bool:
	return _npcs.has(npc_id)


func get_npc(npc_id: String) -> Dictionary:
	if not _npcs.has(npc_id):
		push_error("NPC desconocido: %s" % npc_id)
		return {}
	return _npcs[npc_id]


func role_of(npc_id: String) -> String:
	return get_npc(npc_id).get("role", "")


## Reglas del rol de un NPC: prioridad, plazo, premio y castigo de sus tickets.
func rules_of(npc_id: String) -> Dictionary:
	return _roles.get(role_of(npc_id), {})


## Retrato del NPC, o el genérico si no tiene uno válido.
func portrait_of(npc_id: String) -> Texture2D:
	var path: String = get_npc(npc_id).get("portrait", "")
	return load(path if ResourceLoader.exists(path) else GENERIC_PORTRAIT) as Texture2D


func ids() -> Array:
	return _npcs.keys()


func _is_valid(entry: Variant) -> bool:
	if not entry is Dictionary:
		push_error("Entrada de NPC no válida: %s" % str(entry))
		return false
	for field: String in REQUIRED_FIELDS:
		if not entry.has(field):
			push_error("NPC %s sin campo \"%s\"" % [entry.get("id", "?"), field])
			return false
	if _npcs.has(entry["id"]):
		push_error("NPC duplicado: %s" % entry["id"])
		return false
	if not _roles.has(entry["role"]):
		push_error("NPC %s con rol desconocido: %s" % [entry["id"], entry["role"]])
		return false
	return true
