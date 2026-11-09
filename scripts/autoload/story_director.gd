extends Node
## Modo historia: actos, pistas, decisiones y chismes. Cada tramo de la carrera
## queda bloqueado hasta resolver el acto de la trama que le corresponde.

signal clue_found(id: String)
signal story_changed

const STORY_PATH := "res://data/story.json"
const GOSSIP_PATH := "res://data/gossip.json"
const FRIENDS_PATH := "res://data/friends.json"
## Pistas recientes que caben en la pantalla del celular.
const CASE_CLUES := 2

## Las pruebas de otros sistemas la desactivan para no depender de la trama.
var enabled := true
var act := 1
var clues := {}
var flags := {}
var ending := ""
var _story := {}
var _gossip := {}
var _seen := {}
var _talked_today := {}
var _pending_decision := ""
var _warned_cap := false
var _life := {}
var _episodes_seen := {}
var _decided := {}


func _ready() -> void:
	var story: Variant = JSON.parse_string(FileAccess.get_file_as_string(STORY_PATH))
	var gossip: Variant = JSON.parse_string(FileAccess.get_file_as_string(GOSSIP_PATH))
	if story is Dictionary and gossip is Dictionary:
		_story = story
		for node: Dictionary in gossip["gossip"]:
			_gossip[node["id"]] = node
	else:
		push_error("Datos de historia no válidos")
	var life: Variant = JSON.parse_string(FileAccess.get_file_as_string(FRIENDS_PATH))
	if life is Dictionary:
		_life = life
		for node: Dictionary in life["talks"]:
			_gossip[node["id"]] = node
	else:
		push_error("%s no es válido" % FRIENDS_PATH)
	GameState.reputation_changed.connect(func(_value: float) -> void: _check_act())


func _process(_delta: float) -> void:
	if _pending_decision.is_empty() or get_tree().paused or TicketManager.active != null or TicketManager.repairing:
		return
	var node: Dictionary = _story["decisions"][_pending_decision]
	_pending_decision = ""
	AudioDirector.play("stinger")
	EventDirector.event_started.emit(node)


func clue_catalog() -> Dictionary:
	return _story.get("clues", {})


func gossip_nodes() -> Dictionary:
	return _gossip


func decision_ids() -> Array:
	return _story.get("decisions", {}).keys()


## Acto en curso, o vacío si la trama ya terminó.
func current_act() -> Dictionary:
	for entry: Dictionary in _story.get("acts", []):
		if int(entry["act"]) == act:
			return entry
	return {}


## Reputación máxima hasta resolver el acto en curso.
func reputation_cap() -> float:
	if not enabled:
		return float(GameState.MAX_REPUTATION)
	return float(current_act().get("cap", GameState.MAX_REPUTATION))


## Avisa una vez por acto de que hace falta avanzar la trama para ascender.
func warn_cap() -> void:
	if not _warned_cap:
		_warned_cap = true
		GameState.notice.emit("Tu carrera no avanzará más sin resolver la trama. Mira el caso en el celular.")


func has_clue(id: String) -> bool:
	return clues.has(id)


## Registra una pista y lanza la decisión del acto al reunir las necesarias.
func discover(id: String) -> void:
	if not enabled or id.is_empty() or clues.has(id) or not clue_catalog().has(id) or not can_find(id):
		return
	clues[id] = true
	GameState.notice.emit("Pista: %s. %s" % [clue_catalog()[id]["title"], clue_catalog()[id]["text"]])
	clue_found.emit(id)
	story_changed.emit()
	_check_act()


## Una pista de un acto futuro aún no significa nada: se podrá hallar a su tiempo.
func can_find(id: String) -> bool:
	for entry: Dictionary in _story.get("acts", []):
		if id in entry["clues"]:
			return int(entry["act"]) <= act
	return true


func act_progress() -> int:
	var found := 0
	for id: String in current_act().get("clues", []):
		if clues.has(id):
			found += 1
	return found


func set_flag(id: String) -> void:
	if not id.is_empty():
		flags[id] = true


## Cierra el acto actual tras su decisión.
func advance_act() -> void:
	act += 1
	_warned_cap = false
	story_changed.emit()
	_check_act()


func ending_text() -> String:
	return _story.get("endings", {}).get(ending, "")


## Comprueba condiciones de datos: día, acto, marcas, pistas y grupos.
func is_available(requires: Dictionary) -> bool:
	if WorkdayManager.day < int(requires.get("min_day", 0)):
		return false
	if requires.has("act") and act < int(requires["act"]):
		return false
	for id: String in requires.get("flags", []):
		if not flags.has(id):
			return false
	for id: String in requires.get("not_flags", []):
		if flags.has(id):
			return false
	var minimum: Dictionary = requires.get("faction_min", {})
	for faction: String in minimum:
		if Factions.value_of(faction) < int(minimum[faction]):
			return false
	if requires.has("clue") and not clues.has(requires["clue"]):
		return false
	var friends: Dictionary = requires.get("friends_min", {})
	for npc_id: String in friends:
		if Friends.value_of(npc_id) < int(friends[npc_id]):
			return false
	var maximum: Dictionary = requires.get("faction_max", {})
	for faction: String in maximum:
		if Factions.value_of(faction) > int(maximum[faction]):
			return false
	return true


## Chisme que este NPC puede contar hoy, o vacío.
func next_gossip(npc_id: String) -> Dictionary:
	if not enabled or _talked_today.get(npc_id, 0) == WorkdayManager.day:
		return {}
	for node: Dictionary in _gossip.values():
		if node["speaker"] != npc_id or node.get("followup", false) or _seen.has(node["id"]):
			continue
		var requires: Dictionary = node.get("requires", {})
		if is_available(requires) and Friends.value_of(npc_id) >= int(requires.get("friend_min", 0)):
			return node
	return {}


## Marca que hoy ya se habló a fondo con ese NPC, sin ventana de chisme.
func mark_talked(npc_id: String) -> void:
	_talked_today[npc_id] = WorkdayManager.day


func talked_today(npc_id: String) -> bool:
	return _talked_today.get(npc_id, 0) == WorkdayManager.day


## Charla de la vida cotidiana en un lugar de descanso; cada una sale una vez.
func break_talk(place: String) -> Dictionary:
	if not enabled:
		return {}
	for talk: Dictionary in DayEvents.data().get("break_talks", []):
		if talk["place"] == place and not _seen.has(talk["id"]) and Friends.value_of(talk["speaker"]) >= 0:
			_seen[talk["id"]] = true
			return talk
	return {}


func lunch_mates() -> Array:
	return _life.get("lunch_mates", [])


## Episodio de hoy: el primero de la trama sin ver, o uno de relleno, más su rumor.
func episode_today() -> Dictionary:
	var pick: Dictionary = {}
	for episode: Dictionary in _life.get("episodes", []):
		if not _episodes_seen.has(episode["id"]) and is_available(episode.get("requires", {})):
			pick = episode.duplicate()
			_episodes_seen[episode["id"]] = true
			break
	if pick.is_empty():
		var generic: Array = _life.get("generic_episodes", [])
		pick = generic[WorkdayManager.day % generic.size()].duplicate()
	var rumors: Array = _life.get("rumors", [])
	pick["rumor"] = rumors[WorkdayManager.day % rumors.size()]
	return pick


func start_gossip(node: Dictionary) -> void:
	_seen[node["id"]] = true
	_talked_today[node["speaker"]] = WorkdayManager.day
	EventDirector.event_started.emit(node)


## Aplica los efectos de historia de una opción de diálogo.
func apply_option(option: Dictionary) -> void:
	Factions.change(option.get("factions", {}))
	set_flag(option.get("flag", ""))
	discover(option.get("clue", ""))
	if option.has("ending"):
		ending = option["ending"]
	if option.has("money"):
		GameState.add_money(int(option["money"]))
	if option.get("advance", false):
		advance_act()


## Líneas de la pestaña Caso del celular.
func case_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	var entry := current_act()
	if entry.is_empty():
		lines.append("Caso cerrado.")
	else:
		lines.append("Acto %d: %s" % [act, entry["title"]])
		lines.append(entry["goal"])
		lines.append("Pistas: %d de %d" % [mini(act_progress(), int(entry["needed"])), int(entry["needed"])])
	var ids := clues.keys()
	for id: String in ids.slice(maxi(ids.size() - CASE_CLUES, 0)):
		lines.append("- %s" % clue_catalog()[id]["title"])
	lines.append(_standing_line(["direccion", "tecnicos", "desarrollo"]))
	lines.append(_standing_line(["administracion", "servicios"]))
	return lines


func _standing_line(groups: Array) -> String:
	var parts := PackedStringArray()
	for faction: String in groups:
		parts.append("%s %+d" % [Factions.NAMES[faction].left(3), Factions.value_of(faction)])
	return "  ".join(parts)


func reset() -> void:
	act = 1
	clues.clear()
	flags.clear()
	ending = ""
	_seen.clear()
	_talked_today.clear()
	_pending_decision = ""
	_warned_cap = false
	_episodes_seen.clear()
	_decided.clear()
	Factions.reset()
	Friends.reset()
	story_changed.emit()


func _check_act() -> void:
	var entry := current_act()
	if entry.is_empty() or act_progress() < int(entry["needed"]):
		return
	if GameState.reputation >= float(entry["ready"]) and not _decided.has(entry["decision"]):
		_decided[entry["decision"]] = true
		_pending_decision = entry["decision"]
