extends Node
## Comprueba que el rol de quien abre el ticket cambia plazo, premio y castigo.
##
## Uso:  godot --headless --path . res://tools/check_roles.tscn

const FIXTURE := "user://npcs_roles.json"
const IDS := {"soporte": "t_soporte", "usuario_comun": "t_usuario", "jefe_departamento": "t_jefe", "directiva": "t_directiva"}
## Rol: plazo de 100 s, premio de 20, reputación perdida, amonestaciones.
const EXPECTED := {
	"soporte": [125.0, 10, -2, 0],
	"usuario_comun": [100.0, 20, -5, 1],
	"jefe_departamento": [80.0, 25, -10, 1],
	"directiva": [60.0, 30, -15, 2],
}

var fails := 0


func check(label: String, ok: bool, info: Variant = "") -> void:
	if not ok:
		fails += 1
	print("%s %s %s" % ["OK  " if ok else "FAIL", label, info])


func ticket_for(role: String) -> TicketData:
	var ticket := TicketData.new()
	ticket.title = "Prueba"
	ticket.done_text = "Hecho"
	ticket.requester_id = IDS[role]
	ticket.target_id = "equipo"
	ticket.reputation = 20
	ticket.time_limit = 100
	return ticket


func clean() -> void:
	GameState.reset()
	GameState.reputation = 100
	TicketManager.reset()


func _ready() -> void:
	CareerProfile.use_blank_profile()
	WorkdayManager.enabled = false
	EventDirector.enabled = false
	WorkdayManager.reputation_pace = 1.0
	await get_tree().process_frame
	var entries := []
	for role: String in IDS:
		entries.append({"id": IDS[role], "name": role, "department": "Pruebas", "role": role,
			"portrait": "res://assets/sprites/npc/portraits/ana.png", "sprite_frame": 0, "dialogue": "Hola"})
	var file := FileAccess.open(FIXTURE, FileAccess.WRITE)
	file.store_string(JSON.stringify({"npcs": entries}))
	file.close()
	NpcDatabase.load_from(FIXTURE)

	for role: String in EXPECTED:
		var want: Array = EXPECTED[role]
		clean()
		TicketManager.accept(ticket_for(role))
		check("plazo " + role, is_equal_approx(TicketManager.time_left, want[0]), TicketManager.time_left)
		check("prioridad " + role, TicketManager.priority() == NpcDatabase.rules_of(IDS[role])["priority"], TicketManager.priority())
		TicketManager.resolve("equipo")
		check("premio " + role, GameState.reputation == 100 + want[1], GameState.reputation)
		clean()
		TicketManager.accept(ticket_for(role))
		TicketManager.time_left = 0.0
		TicketManager._process(0.1)
		check("fallo " + role, GameState.reputation == 100 + want[2] and GameState.warnings == want[3], "rep=%d amon=%d" % [GameState.reputation, GameState.warnings])

	clean()
	GameState.warnings = 2
	var fired := [false]
	GameState.fired.connect(func() -> void: fired[0] = true)
	TicketManager.accept(ticket_for("directiva"))
	TicketManager.time_left = 0.0
	TicketManager._process(0.1)
	check("directiva no pasa del despido", GameState.warnings == GameState.MAX_WARNINGS and fired[0], GameState.warnings)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE))
	NpcDatabase.load_from(NpcDatabase.DATA_PATH)
	clean()
	var clara := TicketManager.next_for("clara")
	TicketManager.accept(clara)
	check("Clara real es critica", TicketManager.priority() == "Crítica" and is_equal_approx(TicketManager.time_left, clara.time_limit * 0.6), TicketManager.time_left)
	print("fallos: ", fails)
	get_tree().quit(1 if fails > 0 else 0)
