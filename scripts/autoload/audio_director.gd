extends Node
## Música en bucle de la oficina y efectos ligados a lo que ocurre en la partida.

const MUSIC_PATH := "res://assets/audio/office_chiptune.wav"
const MUSIC_DB := -5.0
const SFX_DB := -6.0
const SOUNDS := {
	"hit": preload("res://assets/audio/blip.wav"),
	"phone": preload("res://assets/audio/phone.wav"),
	"stamp": preload("res://assets/audio/stamp.wav"),
	"alarm": preload("res://assets/audio/alarm.wav"),
	"keys": preload("res://assets/audio/keyboard.wav"),
	"stinger": preload("res://assets/audio/stinger.wav"),
}

var _music := AudioStreamPlayer.new()
var _sfx := AudioStreamPlayer.new()
## Si debe sonar: un corte inesperado se recupera solo.
var _wanted := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var track: AudioStreamWAV = load(MUSIC_PATH)
	track.loop_mode = AudioStreamWAV.LOOP_FORWARD
	track.loop_end = roundi(track.get_length() * track.mix_rate)
	_music.stream = track
	_music.bus = Settings.MUSIC_BUS
	_sfx.bus = Settings.SFX_BUS
	_music.volume_db = MUSIC_DB
	_sfx.volume_db = SFX_DB
	add_child(_music)
	add_child(_sfx)
	GameState.warned.connect(play.bind("stamp"))
	GameState.stress_crisis.connect(play.bind("alarm"))
	TicketQueue.ticket_added.connect(func(_id: String) -> void: play("phone"))
	TicketManager.ticket_solved.connect(play.bind("keys"))
	StoryDirector.clue_found.connect(func(_id: String) -> void: play("stinger"))


func _process(_delta: float) -> void:
	if _wanted and not _music.playing:
		_music.play()


func play_music() -> void:
	_wanted = true
	if not _music.playing:
		_music.play()


func stop_music() -> void:
	_wanted = false
	_music.stop()


func is_music_playing() -> bool:
	return _music.playing


func play(sound: String) -> void:
	_sfx.stream = SOUNDS[sound]
	_sfx.play()
