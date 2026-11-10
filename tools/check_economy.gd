extends Node
## Comprueba la curva semanal, los incidentes críticos, los gastos y las mejoras nuevas.
##
## Uso:  godot --path . res://tools/check_economy.tscn

var fails := 0


func check(label: String, ok: bool, info: Variant = "") -> void:
	if not ok:
		fails += 1
	print("%s %s %s" % ["OK  " if ok else "FAIL", label, info])


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	CareerProfile.use_blank_profile()
	StoryDirector.enabled = true
	EventDirector.enabled = false
	await get_tree().process_frame
	var room: Node = (load("res://scenes/world/office.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(room)
	get_tree().current_scene = room
	await frames(6)
	room.get_node("EpisodeCard/Panel").hide()
	get_tree().paused = false

	# Curva por semanas.
	var curve: Array = []
	for week in 6:
		WorkdayManager.day = week * 5 + 1
		curve.append([WorkdayManager.queue_stress(), WorkdayManager.difficulty("wait"), WorkdayManager.difficulty("incident_chance")])
	var rising := true
	for i in curve.size() - 1:
		rising = rising and curve[i + 1][0] >= curve[i][0] and curve[i + 1][1] <= curve[i][1] and curve[i + 1][2] >= curve[i][2]
	check("presion creciente", rising, curve)
	check("sin incidentes la primera semana", curve[0][2] == 0.0)
	check("ultima semana se mantiene", curve[4] == curve[5])
	WorkdayManager.day = 6

	# Incidente crítico.
	TicketQueue.reset()
	TicketQueue._timer = 999.0
	var alerts: Array = []
	Incidents.started.connect(func(ids: Array) -> void: alerts.append(ids))
	check("dispara el incidente", Incidents.trigger())
	var ids: Array = alerts[0]
	check("varias averias a la vez", ids.size() >= Incidents.SIZE_MIN and ids.all(func(id: String) -> bool: return TicketQueue.pending.has(id)), ids)
	var npc_id: String = ids[0]
	var normal_wait: float = TicketQueue.pending[npc_id]["limit"] / Incidents.WAIT_SCALE
	check("menos paciencia", TicketQueue.pending[npc_id]["limit"] < normal_wait)
	check("marcado en el celular", room.get_node("Phone").sorted_tickets()[0]["priority"] == "CRÍTICO")
	GameState.stress = 0.0
	await get_tree().create_timer(1.0).timeout
	var expected := ids.size() * Incidents.QUEUE_STRESS_SCALE * WorkdayManager.queue_stress()
	check("estresa el doble", GameState.stress > expected * 0.7, "%.2f de %.2f" % [GameState.stress, expected])

	# Resolverlo todo da prima.
	TicketQueue._timer = 999.0
	var rep_before := GameState.reputation
	var money_before := GameState.money
	var cleans: Array = []
	Incidents.resolved.connect(func(clean: bool) -> void: cleans.append(clean))
	for id: String in ids:
		var ticket: TicketData = TicketQueue.take(id)
		TicketManager.accept(ticket)
		TicketManager.resolve(TicketManager.current_target())
	await frames(2)
	check("incidente limpio", cleans == [true] and Incidents.critical.is_empty())
	check("prima por limpieza", GameState.money == money_before + Incidents.CLEAN_BONUS_MONEY and GameState.reputation > rep_before + Incidents.CLEAN_BONUS_REPUTATION, GameState.money)

	# Dejar caducar uno pesa.
	alerts.clear()
	cleans.clear()
	Incidents.trigger()
	var victim: String = alerts[0][0]
	GameState.stress = 0.0
	TicketQueue.pending[victim]["wait"] = 0.01
	await frames(3)
	check("caducar un critico estresa mas", GameState.stress >= Incidents.MISSED_STRESS + TicketQueue.EXPIRE_STRESS - 1.0, GameState.stress)
	for id: String in alerts[0]:
		if TicketQueue.pending.has(id):
			TicketQueue.pending[id]["wait"] = 0.01
	await frames(3)
	check("incidente con perdidas", cleans == [false], cleans)
	TicketQueue.reset()
	TicketQueue._timer = 999.0

	# Gastos y deuda.
	GameState.money = 0
	GameState.warnings = 0
	WorkdayManager.closed_today = WorkdayManager.quota()
	DayStats.solved = WorkdayManager.quota()
	var summary: Array = []
	WorkdayManager.day_ended.connect(func(s: Dictionary) -> void: summary.append(s), CONNECT_ONE_SHOT)
	var salary := WorkdayManager.salary()
	var costs := WorkdayManager.expenses()
	WorkdayManager.clock = 9999.0
	await frames(3)
	check("paga los gastos", summary[0]["expenses"] == costs and GameState.money == maxi(salary - costs, 0), GameState.money)
	room.get_node("DaySummary/Panel").hide()
	get_tree().paused = false
	WorkdayManager.debt = 20
	GameState.stress = 0.0
	WorkdayManager.next_day()
	check("la deuda estresa", GameState.stress > 0.0 and WorkdayManager.morning_note.contains("debes"), WorkdayManager.morning_note)

	# Mejoras nuevas.
	var bike: Dictionary = Upgrades.catalog.filter(func(e: Dictionary) -> bool: return e["id"] == "bicicleta")[0]
	GameState.money = 1000
	var before := WorkdayManager.expenses()
	Upgrades.buy(bike)
	check("la bici ahorra", WorkdayManager.expenses() == before - 15, WorkdayManager.expenses())
	var mentor: Dictionary = Upgrades.catalog.filter(func(e: Dictionary) -> bool: return e["id"] == "mentor")[0]
	Upgrades.buy(mentor)
	check("la mentoria premia", is_equal_approx(Upgrades.reward_scale(), 1.1))
	var cheapest := 99999
	for entry: Dictionary in Upgrades.catalog:
		cheapest = mini(cheapest, int(entry["prices"][0]))
	check("mejoras mas caras", cheapest >= 250, cheapest)
	print("fallos: ", fails)
	get_tree().quit(1 if fails > 0 else 0)
