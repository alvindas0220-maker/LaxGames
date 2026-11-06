extends Node
## Métricas de la jornada en curso para el informe final.

## Puntuación mínima de cada calificación.
const GRADES := [[90.0, "S"], [75.0, "A"], [60.0, "B"], [45.0, "C"], [0.0, "D"]]

var solved := 0
var lost := 0
var tool_errors := 0
var hits := 0
var misses := 0
var stress_peak := 0.0
var _solve_seconds := 0.0


func _ready() -> void:
	TicketManager.ticket_solved.connect(_on_solved)
	TicketManager.ticket_lost.connect(_on_lost)
	TicketManager.tool_error.connect(func() -> void: tool_errors += 1)
	TicketQueue.ticket_expired.connect(_on_lost)
	GameState.stress_changed.connect(func(value: float) -> void: stress_peak = maxf(stress_peak, value))


func average_seconds() -> float:
	return _solve_seconds / solved if solved > 0 else 0.0


## Porcentaje de aciertos en el minijuego.
func accuracy() -> float:
	return 100.0 * hits / (hits + misses) if hits + misses > 0 else 100.0


## De 0 a 100: cuota, precisión, tickets conservados y calma.
func score(quota: int) -> float:
	var delivered := minf(float(solved) / maxi(quota, 1), 1.0)
	var kept := float(solved) / maxi(solved + lost, 1)
	return delivered * 50.0 + accuracy() * 0.2 + kept * 20.0 + (100.0 - stress_peak) * 0.1


func grade(quota: int) -> String:
	var points := score(quota)
	for entry: Array in GRADES:
		if points >= entry[0]:
			return entry[1]
	return GRADES[-1][1]


func reset() -> void:
	solved = 0
	lost = 0
	tool_errors = 0
	hits = 0
	misses = 0
	stress_peak = GameState.stress
	_solve_seconds = 0.0


func _on_solved() -> void:
	solved += 1
	_solve_seconds += TicketManager.last_solve_seconds


func _on_lost() -> void:
	lost += 1
