extends Node
## Muestra lo que dice un NPC con su nombre y retrato, leídos de NpcDatabase.

signal line_shown(npc_id: String, text: String)

var _greeted := {}


## El primer encuentro antepone el diálogo inicial del NPC.
func speak(npc_id: String, text := "") -> void:
	var line := text
	if not _greeted.has(npc_id):
		_greeted[npc_id] = true
		var intro: String = NpcDatabase.get_npc(npc_id).get("dialogue", "")
		line = "%s %s" % [intro, text] if not text.is_empty() else intro
	line_shown.emit(npc_id, CareerProfile.format(line))


func reset() -> void:
	_greeted.clear()
