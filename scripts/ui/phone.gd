class_name Phone
extends CanvasLayer
## Celular del jugador: se abre con Tab o con el botón de la HUD.
## La jornada sigue corriendo mientras se mira la pantalla.

const TABS := ["Estado", "Tickets", "Trabajo", "Tienda", "Caso", "Amigos"]
const SHOP_TAB := 3
const CASE_TAB := 4
const FRIENDS_TAB := 5
const PRIORITY_ORDER := {"CRÍTICO": -1, "Crítica": 0, "Alta": 1, "Normal": 2, "Baja": 3}
const REFRESH_SECONDS := 0.25
const CLOSED_X := 8.0
const OPEN_X := -168.0
const SLIDE_SECONDS := 0.14

var tab := 0
var _shop_choice := 0
var _refresh := 0.0
var _open := false

@onready var _body: Control = $Body
@onready var _tabs: Label = %TabsLabel
@onready var _portrait: TextureRect = %PhonePortrait
@onready var _identity: Label = %IdentityLabel
@onready var _gauges: Control = %PhoneGauges
@onready var _reputation: TextureProgressBar = %PhoneReputation
@onready var _stress: TextureProgressBar = %PhoneStress
@onready var _header: Control = %PhoneHeader
@onready var _text: Label = %ScreenText


func _ready() -> void:
	add_to_group("phone")
	_body.hide()
	_portrait.texture = load(CareerProfile.portrait_path())
	_reputation.max_value = GameState.MAX_REPUTATION
	_stress.max_value = GameState.MAX_STRESS


## Una recarga de escena no debe dejar al personaje bloqueado.
func _exit_tree() -> void:
	if _open:
		GameState.input_locked = false


func _process(delta: float) -> void:
	if not _open:
		return
	if not _can_open():
		close()
		return
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = REFRESH_SECONDS
		refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		toggle()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		select_tab(posmod(tab - 1, TABS.size()))
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		select_tab(posmod(tab + 1, TABS.size()))
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		_move_shop(-1)
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		_move_shop(1)
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		buy_selected()
	else:
		return
	get_viewport().set_input_as_handled()


func toggle() -> void:
	if _open:
		close()
	elif _can_open():
		open()


func open(start_tab := -1) -> void:
	if start_tab >= 0:
		tab = start_tab
	_open = true
	GameState.input_locked = true
	_body.show()
	_body.offset_left = CLOSED_X
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_body, "offset_left", OPEN_X, SLIDE_SECONDS)
	refresh()


func close() -> void:
	_open = false
	GameState.input_locked = false
	_body.hide()


func is_open() -> bool:
	return _open


func select_tab(index: int) -> void:
	tab = index
	refresh()


func buy_selected() -> void:
	if tab != SHOP_TAB:
		return
	if not Upgrades.buy(Upgrades.catalog[_shop_choice]):
		GameState.notice.emit("No te alcanza o ya está al máximo.")
	refresh()


## Tickets en espera y activo, de mayor a menor prioridad y urgencia.
func sorted_tickets() -> Array:
	var rows: Array = []
	if TicketManager.active != null:
		var ticket := TicketManager.active
		rows.append({"rank": PRIORITY_ORDER.get(TicketManager.priority(), 9), "urgency": 2.0, "ticket": ticket,
			"priority": TicketManager.priority(), "seconds": TicketManager.time_left, "active": true})
	for npc_id: String in TicketQueue.pending:
		var entry: Dictionary = TicketQueue.pending[npc_id]
		var priority := "CRÍTICO" if Incidents.is_critical(npc_id) else str(NpcDatabase.rules_of(npc_id)["priority"])
		rows.append({"rank": PRIORITY_ORDER.get(priority, 9), "urgency": TicketQueue.urgency(npc_id), "ticket": entry["ticket"],
			"priority": priority, "seconds": entry["wait"], "active": false})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["urgency"] > b["urgency"] if a["rank"] == b["rank"] else a["rank"] < b["rank"])
	return rows


func refresh() -> void:
	_tabs.text = "< %s %d/%d >" % [TABS[tab], tab + 1, TABS.size()]
	_header.visible = tab == 0
	_gauges.visible = tab == 0
	match tab:
		0:
			_show_status()
		1:
			_show_tickets()
		2:
			_show_work()
		SHOP_TAB:
			_show_shop()
		CASE_TAB:
			_text.text = "\n".join(StoryDirector.case_lines())
		FRIENDS_TAB:
			_show_friends()


func _show_status() -> void:
	_identity.text = "%s\n%s" % [CareerProfile.player_name, GameState.stage_label()]
	_reputation.value = GameState.reputation
	_stress.value = GameState.stress
	_text.text = "%s\n%s  %s\nRep %d%%\nEstrés %d%% %s\nExpediente: %s\nDinero $%d  Café %d" % [
		WorkdayManager.phase(), WorkdayManager.label(), WorkdayManager.clock_text(), GameState.reputation,
		GameState.stress, GameState.stress_level(), GameState.warning_name(), GameState.money, ToolBelt.coffee,
	]


func _show_tickets() -> void:
	var rows := sorted_tickets()
	if rows.is_empty():
		_text.text = "Sin tickets en espera."
		return
	var lines := PackedStringArray()
	for row: Dictionary in rows:
		var ticket: TicketData = row["ticket"]
		var name_of: String = NpcDatabase.get_npc(ticket.requester_id).get("name", "").get_slice(" ", 0)
		lines.append("%s%s %s %ds" % ["> " if row["active"] else "", row["priority"], name_of, ceili(row["seconds"])])
		lines.append(" %s - %s" % [ticket.title, ToolBelt.TOOL_SHORT[ticket.tool]])
	_text.text = "\n".join(lines)


func _show_work() -> void:
	var quota := WorkdayManager.quota()
	var theme := "Hoy: %s\n" % DayEvents.title() if not DayEvents.title().is_empty() else ""
	_text.text = theme + "Cuota: %d de %d\nPerdidos hoy: %d\nPrecisión: %d%%\nFalta para ascenso: %s\nSueldo: $%d  Gastos: $%d\nAhorros: $%d\n\nTeclas: 1 Kit  2 Café\n3 USB  4 Tester  Espacio: usar" % [
		WorkdayManager.closed_today, quota, DayStats.lost, DayStats.accuracy(), _next_promotion(), WorkdayManager.salary(), WorkdayManager.expenses(), GameState.money,
	]


func _show_shop() -> void:
	var lines := PackedStringArray(["Saldo: $%d" % GameState.money])
	for i in Upgrades.catalog.size():
		var entry: Dictionary = Upgrades.catalog[i]
		var cost := "MAX" if Upgrades.is_maxed(entry) else "$%d" % Upgrades.price_of(entry)
		lines.append("%s%s %d %s" % ["> " if i == _shop_choice else "", entry["name"], Upgrades.level_of(entry["id"]), cost])
	lines.append(Upgrades.catalog[_shop_choice]["text"])
	_text.text = "\n".join(lines)


func _show_friends() -> void:
	var known: Array = Friends.points.keys().filter(func(id: String) -> bool: return Friends.value_of(id) > 0)
	known.sort_custom(func(a: String, b: String) -> bool: return Friends.value_of(a) > Friends.value_of(b))
	if known.is_empty():
		_text.text = "Aún no conoces a nadie. Habla con la gente."
		return
	var lines := PackedStringArray()
	for npc_id: String in known.slice(0, 8):
		lines.append("%s: %s" % [NpcDatabase.get_npc(npc_id).get("name", "").get_slice(" ", 0), Friends.tier_name(npc_id)])
	lines.append("Charlas hoy: %d" % Friends.social_today)
	_text.text = "\n".join(lines)


func _move_shop(step: int) -> void:
	if tab == SHOP_TAB:
		_shop_choice = posmod(_shop_choice + step, Upgrades.catalog.size())
		refresh()


func _next_promotion() -> String:
	for stage: Array in GameState.CAREER:
		if GameState.reputation < stage[0]:
			return "%d%%" % ceili(stage[0] - GameState.reputation)
	return "nada"


## Solo durante la jornada o la noche: nunca sobre una ventana que pausa el juego.
func _can_open() -> bool:
	return GameState.night or not get_tree().paused
