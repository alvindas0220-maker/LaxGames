extends Node
## Estado de la partida: amonestaciones, reputación, estrés y etapa de la carrera.

signal warned
signal warnings_changed(count: int)
signal reputation_changed(value: float)
signal stress_changed(value: float)
signal stress_crisis
signal money_changed(value: int)
signal stage_changed(title: String)
signal fired
signal notice(text: String)
signal prompt_changed(text: String)

const MAX_WARNINGS := 3
const MAX_REPUTATION := 200
const MAX_STRESS := 100.0
const SLIPS_PATH := "res://data/slips.json"
## Estrés mínimo de cada tramo del medidor.
const STRESS_LEVELS := [[0.0, "Calma"], [40.0, "Tenso"], [70.0, "Alterado"], [90.0, "Crítico"]]
const WARNING_NAMES := ["Sin amonestaciones", "Amonestación verbal", "Amonestación escrita", "Despido"]
## Reputación mínima y título de cada etapa, de menor a mayor.
const CAREER := [
	[0, "Practicante de Soporte IT"],
	[15, "Junior de Soporte IT"],
	[50, "Técnico de Soporte IT"],
	[100, "Jefe de IT"],
	[110, "Ingeniero en Gran Tecnológica"],
	[200, "Fundador de su Empresa"],
]

var warnings := 0
var reputation := 0.0
var stress := 0.0
## El último despido fue sin responsabilidad patronal.
var money := 0
## Celular abierto: el personaje no recibe órdenes.
var input_locked := false
## Noche en casa: se puede usar el celular con el juego en pausa.
var night := false
var fired_for_cause := false
## Qué dijo el jugador en su desliz grave.
var slip_line := ""
var _slips: Array = []


func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SLIPS_PATH))
	if parsed is Dictionary and parsed.get("slips") is Array:
		_slips = parsed["slips"]
	else:
		push_error("%s no es válido" % SLIPS_PATH)


func stage_title() -> String:
	var title: String = CAREER[0][1]
	for stage: Array in CAREER:
		if reputation >= stage[0]:
			title = stage[1]
	return title


## Puesto para mostrar, concordado con el género.
func stage_label() -> String:
	return CareerProfile.title_of(stage_title())


func warning_name() -> String:
	return WARNING_NAMES[warnings]


func add_warning(reason: String, amount := 1) -> void:
	if warnings >= MAX_WARNINGS:
		return
	warnings = mini(warnings + amount, MAX_WARNINGS)
	warned.emit()
	warnings_changed.emit(warnings)
	notice.emit("%s: %s" % [warning_name(), reason])
	if warnings == MAX_WARNINGS:
		fired.emit()


func remove_warning() -> void:
	warnings = maxi(warnings - 1, 0)
	warnings_changed.emit(warnings)


func add_reputation(amount: float) -> void:
	var before := stage_title()
	var cap := StoryDirector.reputation_cap()
	reputation = clampf(reputation + amount, 0.0, minf(MAX_REPUTATION, maxf(cap, reputation)))
	if amount > 0.0 and reputation >= cap:
		StoryDirector.warn_cap()
	reputation_changed.emit(reputation)
	var after := stage_title()
	if after != before:
		stage_changed.emit(after)
		notice.emit("%s: %s" % ["Ascenso" if amount > 0 else "Descenso", CareerProfile.title_of(after)])


func add_money(amount: int) -> void:
	money = maxi(money + amount, 0)
	money_changed.emit(money)


func stress_level() -> String:
	var level: String = STRESS_LEVELS[0][1]
	for entry: Array in STRESS_LEVELS:
		if stress >= entry[0]:
			level = entry[1]
	return level


## Sube o baja el estrés. Llegar al máximo provoca un desliz imperdonable.
func add_stress(amount: float) -> void:
	if warnings >= MAX_WARNINGS:
		return
	var before := stress_level()
	var scale_up := CareerProfile.stress_scale() * Upgrades.stress_scale() * Friends.stress_scale() * DayEvents.mod("stress", 1.0)
	stress = clampf(stress + amount * (scale_up if amount > 0.0 else 1.0), 0.0, MAX_STRESS)
	stress_changed.emit(stress)
	if stress >= MAX_STRESS:
		_serious_slip()
	elif amount > 0.0 and stress_level() != before and stress_level() == STRESS_LEVELS[-1][1]:
		notice.emit("Estrés crítico: tómate un café (tecla 2) antes de explotar.")


## Despido sin responsabilidad: no hay amonestación que valga.
func _serious_slip() -> void:
	var slip: Dictionary = _slips.pick_random()
	slip_line = slip["line"]
	fired_for_cause = true
	warnings = MAX_WARNINGS
	warnings_changed.emit(warnings)
	stress_crisis.emit()
	fired.emit()


func reset() -> void:
	warnings = 0
	reputation = CareerProfile.start_reputation()
	stress = 0.0
	money = 0
	input_locked = false
	night = false
	fired_for_cause = false
	slip_line = ""
