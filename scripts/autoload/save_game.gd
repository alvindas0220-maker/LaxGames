extends Node
## Guardado de la partida: se escribe cada noche al dormir y se carga con Continuar.
## Cada sistema sabe guardar y restaurar su propio estado.

signal saved

const DEFAULT_PATH := "user://partida.json"
const VERSION := 1

## Las pruebas lo desactivan o usan otra ruta para no tocar la partida del jugador.
var persist := true
var path := DEFAULT_PATH


func has_save() -> bool:
	return persist and FileAccess.file_exists(path)


func save_game() -> void:
	if not persist:
		return
	var data := {
		"version": VERSION,
		"summary": summary_text(),
		"game": GameState.save_state(),
		"workday": WorkdayManager.save_state(),
		"tickets": TicketManager.save_state(),
		"tools": ToolBelt.save_state(),
		"upgrades": Upgrades.save_state(),
		"story": StoryDirector.save_state(),
		"factions": Factions.save_state(),
		"friends": Friends.save_state(),
		"overheard": Overheard.save_state(),
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("No se pudo guardar en %s" % path)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	saved.emit()


## Restaura la partida guardada. Devuelve false si no hay o no es válida.
func load_game() -> bool:
	var data := _read()
	if data.is_empty():
		return false
	WorkdayManager.new_game()
	GameState.load_state(data["game"])
	WorkdayManager.load_state(data["workday"])
	TicketManager.load_state(data["tickets"])
	ToolBelt.load_state(data["tools"])
	Upgrades.load_state(data["upgrades"])
	StoryDirector.load_state(data["story"])
	Factions.load_state(data["factions"])
	Friends.load_state(data["friends"])
	Overheard.load_state(data["overheard"])
	return true


## Resumen de una línea para el menú principal.
func saved_summary() -> String:
	return str(_read().get("summary", ""))


func summary_text() -> String:
	return "%s, %s. %s, %d%%" % [CareerProfile.player_name, WorkdayManager.label(), GameState.stage_label(), GameState.reputation]


func delete() -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _read() -> Dictionary:
	if not has_save():
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or int(parsed.get("version", 0)) != VERSION:
		push_error("Partida guardada no válida o de otra versión")
		return {}
	return parsed
