extends Node
## Herramientas de soporte de la barra rápida: kit, café y memoria USB.

signal changed

enum Tool { KIT, COFFEE, USB }

const START_COFFEE := 3
const TARGET_PLACES := {
	"pc_ana": "el puesto de Ana, en la oficina",
	"impresora": "la oficina, junto a la pared este",
	"proyector": "la sala de reuniones",
	"servidor": "la sala de servidores",
	"router": "la sala de servidores",
}

var selected := Tool.KIT
var coffee := START_COFFEE


## Usa la herramienta elegida. Devuelve true si el personaje debe animarse.
func use() -> bool:
	match selected:
		Tool.KIT:
			return true
		Tool.COFFEE:
			_drink_coffee()
		Tool.USB:
			_run_diagnostic()
	return false


func add_coffee(amount: int) -> void:
	if amount != 0:
		coffee = maxi(coffee + amount, 0)
		changed.emit()


func reset() -> void:
	selected = Tool.KIT
	coffee = START_COFFEE


func _drink_coffee() -> void:
	if coffee == 0:
		GameState.notice.emit("No queda café.")
	elif GameState.warnings == 0:
		GameState.notice.emit("Sin amonestaciones: guarda el café para cuando haga falta.")
	else:
		coffee -= 1
		changed.emit()
		GameState.remove_warning()
		GameState.notice.emit("Café reparador: amonestación retirada. Ahora: %s." % GameState.warning_name())


func _run_diagnostic() -> void:
	var ticket := TicketManager.active
	if ticket == null:
		GameState.notice.emit("Diagnóstico USB: no hay ningún ticket activo.")
	else:
		GameState.notice.emit("Diagnóstico USB: el fallo está en %s." % TARGET_PLACES[ticket.target_id])
