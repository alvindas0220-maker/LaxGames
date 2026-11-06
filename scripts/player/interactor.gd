class_name Interactor
extends Area2D
## Detecta lo interactuable más cercano y lo activa con la acción "interact".

var _target: Interactable


func _physics_process(_delta: float) -> void:
	if has_overlapping_areas() or _target != null:
		_update_target()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _target != null and not GameState.input_locked:
		_target.interact()
		get_viewport().set_input_as_handled()


## Aplica la herramienta al equipo cercano; tiene prioridad el del ticket activo.
## Devuelve false si no hay ninguno al alcance.
func use_tool() -> bool:
	var nearest: Terminal
	var best := INF
	for area in get_overlapping_areas():
		if not area is Terminal:
			continue
		if TicketManager.current_target() == area.target_id:
			area.repair()
			return true
		var distance := global_position.distance_squared_to(area.global_position)
		if distance < best:
			best = distance
			nearest = area
	if nearest != null:
		nearest.repair()
	return nearest != null


func _update_target() -> void:
	var closest: Interactable
	var best := INF
	for area in get_overlapping_areas():
		var distance := global_position.distance_squared_to(area.global_position)
		if area is Interactable and distance < best:
			best = distance
			closest = area
	if closest != _target:
		_target = closest
		GameState.prompt_changed.emit(_target.prompt if _target != null else "")
