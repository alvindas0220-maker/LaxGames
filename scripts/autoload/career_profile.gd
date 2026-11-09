extends Node
## Datos que sobreviven entre partidas: nombre del jugador y liquidación acumulada.
## Un despido con responsabilidad facilita la siguiente partida; un despido sin
## responsabilidad lo borra todo.

const SAVE_PATH := "user://career.json"
const TRAITS_PATH := "res://data/traits.json"
const GENDERS := ["hombre", "mujer"]
const SHEETS := {"hombre": "res://assets/sprites/player/hero_clean.png", "mujer": "res://assets/sprites/player/hero_female.png"}
const PORTRAITS := {"hombre": "res://assets/sprites/npc/portraits/alex.png", "mujer": "res://assets/sprites/npc/portraits/alex_f.png"}
## Puestos en femenino para los textos; los datos usan siempre la forma base.
const FEMININE := {
	"Jefe de IT": "Jefa de IT", "Técnico de Soporte IT": "Técnica de Soporte IT",
	"Ingeniero en Gran Tecnológica": "Ingeniera en Gran Tecnológica", "Fundador de su Empresa": "Fundadora de su Empresa",
}
const DEFAULT_NAME := "Alex"
const MAX_NAME := 14
const MAX_LEVEL := 3
const ALLOWED := "abcdefghijklmnopqrstuvwxyzáéíóúüñ0123456789 .-'"
const REPUTATION_PER_LEVEL := 5.0
const CALM_STRESS_SCALE := 0.85

var player_name := DEFAULT_NAME
## Despidos con responsabilidad acumulados.
var severance_level := 0
var gender := "hombre"
## Rasgos elegidos, por id.
var traits: Array = []
## Catálogo de data/traits.json.
var trait_catalog: Array = []
var max_traits := 2
## Las pruebas lo desactivan para no tocar la partida guardada.
var persist := true


func _ready() -> void:
	var known: Variant = JSON.parse_string(FileAccess.get_file_as_string(TRAITS_PATH))
	if known is Dictionary and known.get("traits") is Array:
		trait_catalog = known["traits"]
		max_traits = int(known["max_traits"])
	else:
		push_error("%s no es válido" % TRAITS_PATH)
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if parsed is Dictionary:
		player_name = str(parsed.get("name", DEFAULT_NAME))
		severance_level = clampi(int(parsed.get("severance", 0)), 0, MAX_LEVEL)
		gender = str(parsed.get("gender", "hombre")) if parsed.get("gender") in GENDERS else "hombre"
		traits = parsed.get("traits", []).filter(func(id: Variant) -> bool: return _trait(str(id)) != {})


## Quita lo que la fuente del juego no puede dibujar.
func clean_name(text: String) -> String:
	var clean := ""
	for character in text:
		if ALLOWED.contains(character.to_lower()):
			clean += character
	return clean.left(MAX_NAME)


func register_name(text: String) -> void:
	var clean := clean_name(text).strip_edges()
	player_name = clean if not clean.is_empty() else DEFAULT_NAME
	_save()


func register_character(new_gender: String, new_traits: Array) -> void:
	gender = new_gender if new_gender in GENDERS else GENDERS[0]
	traits = new_traits.slice(0, max_traits)
	_save()


func is_female() -> bool:
	return gender == "mujer"


func sheet_path() -> String:
	return SHEETS[gender]


func portrait_path() -> String:
	return PORTRAITS[gender]


## Suma de los rasgos elegidos para un tipo de efecto.
func trait_total(effect: String) -> float:
	var total := 0.0
	for id: String in traits:
		var entry := _trait(id)
		if entry.get("effect") == effect:
			total += float(entry["value"])
	return total


## Título del puesto concordado con el género del personaje.
func title_of(stage: String) -> String:
	return FEMININE.get(stage, stage) if is_female() else stage


## Sustituye {player} y {bienvenido} en cualquier texto de datos.
func format(text: String) -> String:
	return text.replace("{player}", player_name).replace("{bienvenido}", "Bienvenida" if is_female() else "Bienvenido")


func start_reputation() -> float:
	return severance_level * REPUTATION_PER_LEVEL


func extra_coffee() -> int:
	return severance_level


## Cuota más baja la primera semana desde la segunda liquidación.
func quota_relief() -> int:
	return 1 if severance_level >= 2 else 0


## El estrés sube más despacio con la tercera liquidación.
func stress_scale() -> float:
	return CALM_STRESS_SCALE if severance_level >= MAX_LEVEL else 1.0


func perks_text() -> String:
	if severance_level == 0:
		return ""
	var perks := PackedStringArray()
	perks.append("+%d%% de reputación inicial" % start_reputation())
	perks.append("+%d de café" % extra_coffee())
	if quota_relief() > 0:
		perks.append("-1 de cuota la primera semana")
	if stress_scale() < 1.0:
		perks.append("estrés más lento")
	return ", ".join(perks)


func fired_with_severance() -> void:
	severance_level = mini(severance_level + 1, MAX_LEVEL)
	_save()


func fired_for_cause() -> void:
	severance_level = 0
	_save()


## Para las pruebas: perfil limpio que no lee ni escribe la partida del jugador.
func use_blank_profile() -> void:
	persist = false
	StoryDirector.enabled = false
	player_name = DEFAULT_NAME
	severance_level = 0
	gender = GENDERS[0]
	traits = []


func _save() -> void:
	if not persist:
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"name": player_name, "severance": severance_level, "gender": gender, "traits": traits}))


func _trait(id: String) -> Dictionary:
	for entry: Dictionary in trait_catalog:
		if entry["id"] == id:
			return entry
	return {}
