extends Node
## Tienda de mejoras pasivas: cada compra sube un nivel y se conserva toda la partida.

signal changed

const DATA_PATH := "res://data/upgrades.json"

var catalog: Array = []
var _levels := {}


func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if parsed is Dictionary and parsed.get("upgrades") is Array:
		catalog = parsed["upgrades"]
	else:
		push_error("%s no es válido" % DATA_PATH)


func level_of(id: String) -> int:
	return int(_levels.get(id, 0))


func is_maxed(entry: Dictionary) -> bool:
	return level_of(entry["id"]) >= entry["prices"].size()


func price_of(entry: Dictionary) -> int:
	return int(entry["prices"][level_of(entry["id"])])


func buy(entry: Dictionary) -> bool:
	if is_maxed(entry) or GameState.money < price_of(entry):
		return false
	GameState.add_money(-price_of(entry))
	_levels[entry["id"]] = level_of(entry["id"]) + 1
	changed.emit()
	return true


func speed_scale() -> float:
	return 1.0 + _total("speed")


func stress_scale() -> float:
	return maxf(0.4, 1.0 - _total("stress"))


func zone_scale() -> float:
	return 1.0 + _total("zone")


func patience_scale() -> float:
	return 1.0 + _total("patience")


func expense_saving() -> int:
	return roundi(_total("expenses"))


func reward_scale() -> float:
	return 1.0 + _total("reward")


func daily_coffee() -> int:
	return roundi(_total("coffee"))


func reset() -> void:
	_levels.clear()
	changed.emit()


## Suma el efecto de todas las mejoras de un tipo según su nivel.
func _total(effect: String) -> float:
	var total := CareerProfile.trait_total(effect)
	for entry: Dictionary in catalog:
		if entry["effect"] == effect:
			total += float(entry["value"]) * level_of(entry["id"])
	return total
