extends Node
## Herramientas de soporte de la barra rápida: kit, café, memoria USB y tester.

signal changed

enum Tool { KIT, COFFEE, USB, TESTER }

const START_COFFEE := 3
const MAX_COFFEE := 6
const COFFEE_RELIEF := 35.0
## Nombre de cada herramienta en data/tickets.json.
const TOOL_IDS := {Tool.KIT: "kit", Tool.COFFEE: "cafe", Tool.USB: "usb", Tool.TESTER: "tester"}
const TOOL_LABELS := {"kit": "el kit (1)", "usb": "la memoria USB (3)", "tester": "el tester de red (4)"}
const TOOL_SHORT := {"kit": "Kit (1)", "usb": "USB (3)", "tester": "Tester (4)"}
const TARGET_PLACES := {
	"pc_ana": "el puesto de Ana, en la oficina",
	"impresora": "la oficina, junto a la pared este",
	"proyector": "la sala de reuniones",
	"servidor": "la sala de servidores",
	"router": "la sala de servidores",
	"switch": "Infraestructura, junto al router",
	"pc_helpdesk": "el puesto de Helpdesk",
	"pc_dev": "un puesto de Desarrollo",
	"build_server": "Desarrollo, al fondo",
	"pc_jefatura": "la oficina de Jefatura de IT",
	"pc_gerencia": "Gerencia, en el ala sur",
	"rack_raid": "el rack RAID, en Infraestructura",
	"biometrico": "el lector de asistencia, en el pasillo norte",
	"laptop_ejecutiva": "el portátil ejecutivo, en Gerencia",
	"hvac": "la climatización, en Infraestructura",
	"camara": "la cámara del pasillo sur",
	"estacion_trabajo": "la estación de trabajo de Desarrollo",
}

var selected := Tool.KIT
var coffee := START_COFFEE
## Último día en que la cafetería invitó al café.
var free_coffee_day := 0


## Usa la herramienta elegida. Devuelve true si hay que aplicarla a un equipo.
func use() -> bool:
	if selected == Tool.COFFEE:
		_drink_coffee()
		return false
	return true


## La herramienta se usó sin ningún equipo delante.
func miss() -> void:
	if selected == Tool.USB:
		_run_diagnostic()


func selected_id() -> String:
	return TOOL_IDS[selected]


func tool_label(tool_id: String) -> String:
	return TOOL_LABELS[tool_id]


func add_coffee(amount: int) -> void:
	if amount != 0:
		coffee = clampi(coffee + amount, 0, MAX_COFFEE)
		changed.emit()


func reset() -> void:
	selected = Tool.KIT
	coffee = START_COFFEE + CareerProfile.extra_coffee()
	free_coffee_day = 0


func _drink_coffee() -> void:
	if coffee == 0:
		GameState.notice.emit("No queda café.")
	elif GameState.stress <= 0.0:
		GameState.notice.emit("Sin estrés: guarda el café para cuando haga falta.")
	else:
		coffee -= 1
		changed.emit()
		GameState.add_stress(-COFFEE_RELIEF)
		GameState.notice.emit("Café: recuperas la cordura. Estrés al %d%%." % GameState.stress)


func _run_diagnostic() -> void:
	if TicketManager.active == null:
		GameState.notice.emit("Diagnóstico USB: no hay ningún ticket activo.")
	else:
		GameState.notice.emit("Diagnóstico USB: %s en %s. Usa %s." % [TicketManager.current_fault().get("name", ""), TARGET_PLACES[TicketManager.current_target()], tool_label(TicketManager.current_tool())])


func save_state() -> Dictionary:
	return {"coffee": coffee, "free_coffee_day": free_coffee_day}


func load_state(data: Dictionary) -> void:
	coffee = int(data["coffee"])
	free_coffee_day = int(data["free_coffee_day"])
	changed.emit()
