extends Node
## Opciones del jugador: volumen de música y efectos, y pantalla completa.
## Se guardan aparte de la partida, en user://opciones.cfg.

signal changed

const PATH := "user://opciones.cfg"
const MUSIC_BUS := "Musica"
const SFX_BUS := "Efectos"
const STEP := 0.1

var music := 0.8
var sfx := 0.8
var fullscreen := false
## Las pruebas lo desactivan para no tocar las opciones del jugador.
var persist := true


func _ready() -> void:
	for bus: String in [MUSIC_BUS, SFX_BUS]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		music = clampf(float(config.get_value("audio", "musica", music)), 0.0, 1.0)
		sfx = clampf(float(config.get_value("audio", "efectos", sfx)), 0.0, 1.0)
		fullscreen = bool(config.get_value("pantalla", "completa", fullscreen))
	apply()


func set_music(value: float) -> void:
	music = clampf(snappedf(value, STEP), 0.0, 1.0)
	_changed()


func set_sfx(value: float) -> void:
	sfx = clampf(snappedf(value, STEP), 0.0, 1.0)
	_changed()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_changed()


func apply() -> void:
	_set_bus(MUSIC_BUS, music)
	_set_bus(SFX_BUS, sfx)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


func _set_bus(bus: String, value: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_mute(index, value <= 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.001)))


func _changed() -> void:
	apply()
	changed.emit()
	if not persist:
		return
	var config := ConfigFile.new()
	config.set_value("audio", "musica", music)
	config.set_value("audio", "efectos", sfx)
	config.set_value("pantalla", "completa", fullscreen)
	config.save(PATH)
