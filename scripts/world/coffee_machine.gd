class_name CoffeeMachine
extends Interactable
## Cafetera de la cafetería: una pausa corta que baja el estrés y a veces trae charla.

const RELIEF := 8.0
## En la hora del almuerzo la pausa cunde más.
const LUNCH_FACTOR := 2.0
## Segundos de jornada entre dos pausas.
const COOLDOWN := 40.0

var _ready_at := -INF


func interact() -> void:
	if DayEvents.has_flag("sin_cafe"):
		GameState.notice.emit("La cafetera está rota. Hoy toca sobrevivir sin café.")
		return
	if WorkdayManager.clock < _ready_at:
		GameState.notice.emit("Acabas de tomarte un café. No abuses.")
		return
	_ready_at = WorkdayManager.clock + COOLDOWN
	var relief := RELIEF * (LUNCH_FACTOR if WorkdayManager.in_lunch() else 1.0)
	GameState.add_stress(-relief)
	Friends.mark_social()
	var talk := StoryDirector.break_talk("cafe")
	if talk.is_empty():
		GameState.notice.emit("Un café en la barra. Estrés al %d%%." % GameState.stress)
	else:
		EventDirector.event_started.emit(talk)
