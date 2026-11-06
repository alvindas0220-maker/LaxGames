class_name Terminal
extends Interactable
## Equipo de la oficina que puede ser el objetivo de un ticket.

const FAULT_INK := Color8(26, 20, 32)
const FAULT_LIGHT := Color8(255, 72, 60)

@export var target_id := ""
## Fotograma de office_props.png.
@export_range(0, 5) var look := 0

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("terminals")
	_sprite.frame = look
	TicketManager.ticket_accepted.connect(func(_t: TicketData) -> void: queue_redraw())
	TicketManager.ticket_closed.connect(queue_redraw)


func _process(_delta: float) -> void:
	if is_faulty():
		queue_redraw()


## Este equipo es el que falla en el paso actual del ticket activo.
func is_faulty() -> bool:
	return TicketManager.current_target() == target_id


## Testigo rojo parpadeante sobre el equipo averiado.
func _draw() -> void:
	if is_faulty() and Time.get_ticks_msec() / 300 % 2 == 0:
		draw_rect(Rect2(-2, -13, 4, 3), FAULT_INK)
		draw_rect(Rect2(-1, -12, 2, 1), FAULT_LIGHT)


## Revisar un equipo solo informa: repararlo exige su herramienta.
func interact() -> void:
	if TicketManager.current_target() == target_id:
		var fault := TicketManager.current_fault()
		GameState.notice.emit("%s %s. Elige %s y úsalo con Espacio." % [fault.get("symptom", ""), fault.get("name", ""), ToolBelt.tool_label(TicketManager.current_tool())])
	else:
		GameState.notice.emit("Este equipo funciona bien.")


func repair() -> void:
	if not TicketManager.try_repair(target_id, ToolBelt.selected_id()):
		GameState.notice.emit("Este equipo funciona bien.")
