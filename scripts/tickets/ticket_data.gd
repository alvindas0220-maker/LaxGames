class_name TicketData
extends RefCounted
## Incidencia que un NPC encarga al jugador. Se carga de data/tickets.json.

var id := ""
var title := ""
var request := ""
## NPC que abre el ticket.
var requester_id := ""
## Equipo que hay que reparar.
var target_id := ""
var done_text := ""
var reputation := 10
## Segundos para resolverlo antes de la penalización de su rol.
var time_limit := 60
## Aciertos del minijuego necesarios en cada paso.
var repairs := 1
## Avería técnica en data/faults.json.
var fault := ""
## Herramienta obligatoria: "kit", "usb" o "tester".
var tool := "kit"
## Pasos posteriores, cada uno con "target", "fault" y "tool".
var chain: Array = []
## Primera jornada en la que puede aparecer.
var min_day := 1


static func from_dict(data: Dictionary) -> TicketData:
	var ticket := TicketData.new()
	ticket.id = data["id"]
	ticket.title = data["title"]
	ticket.request = data["request"]
	ticket.requester_id = data["requester"]
	ticket.target_id = data["target"]
	ticket.done_text = data["done"]
	ticket.reputation = int(data["reputation"])
	ticket.time_limit = int(data["time_limit"])
	ticket.repairs = int(data["repairs"])
	ticket.fault = data.get("fault", "")
	ticket.tool = data.get("tool", "kit")
	ticket.chain = data.get("chain", [])
	ticket.min_day = int(data["min_day"])
	return ticket
