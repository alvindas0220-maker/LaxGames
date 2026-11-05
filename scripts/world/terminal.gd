class_name Terminal
extends Interactable
## Equipo de la oficina que puede ser el objetivo de un ticket.

@export var target_id := ""
## Fotograma de office_props.png.
@export_range(0, 3) var look := 0

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_sprite.frame = look


## Revisar un equipo solo informa: repararlo exige el kit.
func interact() -> void:
	if TicketManager.active != null and TicketManager.active.target_id == target_id:
		GameState.notice.emit("Aquí está la avería. Elige el kit (1) y úsalo con Espacio.")
	else:
		GameState.notice.emit("Este equipo funciona bien.")


func repair() -> void:
	if not TicketManager.repair(target_id):
		GameState.notice.emit("Este equipo funciona bien.")
