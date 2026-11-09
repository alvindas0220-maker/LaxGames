class_name QaLog
extends Logger
## Informe del bot: eventos con hora, métricas y errores capturados del motor.
## Es un Logger para enterarse de los errores de script aunque nadie los provoque
## a propósito; Godot lo llama desde cualquier hilo.

const DEFAULT_PATH := "user://qa_report.txt"
## Mensajes del motor que no indican un fallo del juego.
const IGNORED := ["resources still in use", "RID allocations", "BUG: Unreferenced static string"]

var path := DEFAULT_PATH
## Apagado no anota nada: la partida normal no llena la consola.
var enabled := false
var problems: Array[String] = []
var errors: Array[String] = []
var _lines: Array[String] = []
var _started_ms := Time.get_ticks_msec()
var _mutex := Mutex.new()


func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	var text := "%s (%s:%d en %s)" % [rationale if not rationale.is_empty() else code, file, line, function]
	for ignored: String in IGNORED:
		if text.contains(ignored):
			return
	_mutex.lock()
	errors.append(text)
	_mutex.unlock()


func elapsed() -> float:
	return (Time.get_ticks_msec() - _started_ms) / 1000.0


func note(text: String) -> void:
	if not enabled:
		return
	var line := "[%7.1f] %s" % [elapsed(), text]
	_mutex.lock()
	_lines.append(line)
	_mutex.unlock()
	print("QA ", line)


## Registra un bloqueo o error de lógica.
func problem(kind: String, text: String) -> void:
	_mutex.lock()
	problems.append("%s: %s" % [kind, text])
	_mutex.unlock()
	note("PROBLEMA %s: %s" % [kind, text])


func write(summary: PackedStringArray) -> void:
	_mutex.lock()
	var out := PackedStringArray(["=== INFORME DEL BOT DE PRUEBAS ==="])
	out.append_array(summary)
	out.append("")
	out.append("--- Problemas: %d ---" % problems.size())
	out.append_array(PackedStringArray(_unique(problems)))
	out.append("")
	out.append("--- Errores del motor: %d ---" % errors.size())
	out.append_array(PackedStringArray(_unique(errors)))
	out.append("")
	out.append("--- Registro ---")
	out.append_array(PackedStringArray(_lines))
	_mutex.unlock()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(out) + "\n")
	print("QA informe en: ", ProjectSettings.globalize_path(path))


## Agrupa repeticiones para que un fallo en bucle no tape los demás.
func _unique(items: Array[String]) -> Array[String]:
	var counts := {}
	for item: String in items:
		counts[item] = int(counts.get(item, 0)) + 1
	var result: Array[String] = []
	for item: String in counts:
		result.append("%dx %s" % [counts[item], item])
	return result
