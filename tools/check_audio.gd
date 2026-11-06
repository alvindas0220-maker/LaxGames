extends Node
## Mide la señal real del bus Master: reproducir no basta, tiene que sonar.
##
## Uso:  godot --path . res://tools/check_audio.tscn

var fails := 0


func check(label: String, ok: bool, info: Variant = "") -> void:
	if not ok:
		fails += 1
	print("%s %s %s" % ["OK  " if ok else "FAIL", label, info])


## Volumen máximo en dB durante unos segundos.
func listen(seconds: float) -> float:
	var loudest := -200.0
	var left := seconds
	while left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()
		loudest = maxf(loudest, AudioServer.get_bus_peak_volume_left_db(0, 0))
	return loudest


func _ready() -> void:
	CareerProfile.use_blank_profile()
	WorkdayManager.enabled = true
	EventDirector.enabled = false
	await get_tree().process_frame
	print("driver: ", AudioServer.get_driver_name(), " buses: ", AudioServer.bus_count, " mudo: ", AudioServer.is_bus_mute(0), " volumen: ", AudioServer.get_bus_volume_db(0))
	var track: AudioStreamWAV = AudioDirector._music.stream
	print("pista: formato=%d mezcla=%d largo=%.1f bucle=%d..%d" % [track.format, track.mix_rate, track.get_length(), track.loop_begin, track.loop_end])
	var room: Node = (load("res://scenes/world/office.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(room)
	get_tree().current_scene = room
	await get_tree().process_frame
	check("reproductor activo", AudioDirector.is_music_playing())
	var start := await listen(1.5)
	check("suena al entrar", start > -40.0, "%.1f dB" % start)
	AudioDirector._music.seek(track.get_length() - 1.0)
	await listen(0.5)
	var loop := await listen(2.0)
	check("sigue sonando tras el bucle", AudioDirector.is_music_playing() and loop > -40.0, "%.1f dB en %.1f s" % [loop, AudioDirector._music.get_playback_position()])
	get_tree().paused = true
	var paused := await listen(1.0)
	check("suena en pausa", paused > -40.0, "%.1f dB" % paused)
	get_tree().paused = false
	print("fallos: ", fails)
	get_tree().quit(1 if fails > 0 else 0)
