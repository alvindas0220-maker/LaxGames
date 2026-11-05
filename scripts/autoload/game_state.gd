extends Node
## Estado de la partida: amonestaciones, reputación y etapa de la carrera.

signal warned
signal warnings_changed(count: int)
signal reputation_changed(value: int)
signal stage_changed(title: String)
signal fired
signal notice(text: String)
signal prompt_changed(text: String)

const MAX_WARNINGS := 3
const MAX_REPUTATION := 200
const WARNING_NAMES := ["Sin amonestaciones", "Amonestación verbal", "Amonestación escrita", "Despido"]
## Reputación mínima y título de cada etapa, de menor a mayor.
const CAREER := [
	[0, "Junior de Soporte IT"],
	[50, "Técnico de Soporte IT"],
	[100, "Jefe de IT"],
	[110, "Ingeniero en Gran Tecnológica"],
	[200, "Fundador de su Empresa"],
]

var warnings := 0
var reputation := 0


func stage_title() -> String:
	var title: String = CAREER[0][1]
	for stage: Array in CAREER:
		if reputation >= stage[0]:
			title = stage[1]
	return title


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


func add_reputation(amount: int) -> void:
	var before := stage_title()
	reputation = clampi(reputation + amount, 0, MAX_REPUTATION)
	reputation_changed.emit(reputation)
	var after := stage_title()
	if after != before:
		stage_changed.emit(after)
		notice.emit("%s: %s" % ["Ascenso" if amount > 0 else "Descenso", after])


func reset() -> void:
	warnings = 0
	reputation = 0
