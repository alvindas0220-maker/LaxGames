class_name HUD
extends CanvasLayer
## Muestra la carrera del jugador: reloj, estrés, amonestaciones, reputación, ticket y avisos.

## Alto lógico de la interfaz: se escala a múltiplos enteros para mantener el píxel.
const BASE_HEIGHT := 216
const NOTICE_SECONDS := 6.0
## A partir de este estrés la etiqueta se pone en rojo.
const STRESS_ALERT := 70.0
const STRESS_ALERT_COLOR := Color(1.0, 0.35, 0.3)
const STRESS_TENSE := 40.0
const STRESS_TENSE_COLOR := Color(1.0, 0.8, 0.35)
## Estrés a partir del cual la pantalla late en rojo.
const STRESS_CRITICAL := 90.0
const PULSE_SPEED := 0.008
const PULSE_ALPHA := 0.16

@export var player: Node2D
@export var world_layer: TileMapLayer
@export var warning_on: Texture2D
@export var warning_off: Texture2D

var _notice_left := 0.0

@onready var _root: Control = $Root
@onready var _warnings: HBoxContainer = %Warnings
@onready var _day_label: Label = %DayLabel
@onready var _stress_bar: TextureProgressBar = %StressBar
@onready var _stress_vignette: ColorRect = %StressVignette
@onready var _phone_button: HudSlot = %PhoneButton
@onready var _minimap: Minimap = %Minimap
@onready var _ticket_panel: Control = %TicketPanel
@onready var _ticket_label: Label = %TicketLabel
@onready var _dialog_panel: Control = %DialogPanel
@onready var _dialog_label: Label = %DialogLabel
@onready var _speaker_label: Label = %SpeakerLabel
@onready var _speaker_portrait: TextureRect = %SpeakerPortrait
@onready var _prompt_label: Label = %PromptLabel


func _ready() -> void:
	get_viewport().size_changed.connect(_fit_to_viewport)
	_fit_to_viewport()
	if world_layer and player:
		_minimap.setup(world_layer, player)
	_build_warnings()
	_dialog_panel.hide()
	_ticket_panel.hide()
	_phone_button.gui_input.connect(_on_phone_button_input)
	TicketQueue.changed.connect(_refresh_phone_badge)
	_refresh_phone_badge()
	_prompt_label.text = ""
	GameState.warnings_changed.connect(_on_warnings_changed)
	GameState.stress_changed.connect(_on_stress_changed)
	GameState.notice.connect(_on_notice)
	DialogueManager.line_shown.connect(_on_line_shown)
	GameState.prompt_changed.connect(_on_prompt_changed)
	TicketManager.ticket_accepted.connect(_on_ticket_accepted)
	TicketManager.ticket_closed.connect(_ticket_panel.hide)
	_on_warnings_changed(GameState.warnings)
	_on_stress_changed(GameState.stress)


func _process(delta: float) -> void:
	var lunch := " Almuerzo" if WorkdayManager.in_lunch() else ""
	_day_label.text = "%s  %d/%d%s" % [WorkdayManager.clock_text(), WorkdayManager.closed_today, WorkdayManager.quota(), lunch]
	_prompt_label.visible = not TicketManager.repairing
	_stress_vignette.visible = GameState.stress >= STRESS_CRITICAL
	if _stress_vignette.visible:
		_stress_vignette.color.a = PULSE_ALPHA * (0.5 + 0.5 * sin(Time.get_ticks_msec() * PULSE_SPEED))
	if _dialog_panel.visible:
		_notice_left -= delta
		if _notice_left <= 0.0:
			_dialog_panel.hide()
	if TicketManager.active != null:
		var ticket := TicketManager.active
		var progress := " %d/%d" % [TicketManager.repairs_done, ticket.repairs] if ticket.repairs > 1 else ""
		var step := " paso %d/%d" % [TicketManager.stage + 1, ticket.chain.size() + 1] if not ticket.chain.is_empty() else ""
		_ticket_label.text = "[%s] %s%s%s  %ds\n%s - %s" % [TicketManager.priority(), ticket.title, step, progress, ceili(TicketManager.time_left), TicketManager.current_step(), ToolBelt.TOOL_SHORT[TicketManager.current_tool()]]


func _fit_to_viewport() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var ui_scale := maxf(1.0, floorf(viewport_size.y / BASE_HEIGHT))
	_root.scale = Vector2.ONE * ui_scale
	_root.size = viewport_size / ui_scale


func _build_warnings() -> void:
	for i in GameState.MAX_WARNINGS:
		var icon := TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_warnings.add_child(icon)


func _on_warnings_changed(count: int) -> void:
	for i in GameState.MAX_WARNINGS:
		var icon: TextureRect = _warnings.get_child(i)
		icon.texture = warning_on if i < count else warning_off


func _on_stress_changed(value: float) -> void:
	_stress_bar.value = value


## El número del botón avisa de cuántos tickets esperan.
func _refresh_phone_badge() -> void:
	_phone_button.set_count(TicketQueue.pending.size())


func _on_phone_button_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_tree().call_group("phone", "toggle")


func _on_notice(text: String) -> void:
	_speaker_label.hide()
	_speaker_portrait.hide()
	_show_text(text)


func _on_line_shown(npc_id: String, text: String) -> void:
	var npc := NpcDatabase.get_npc(npc_id)
	_speaker_label.text = "%s - %s" % [npc.get("name", ""), npc.get("department", "")]
	_speaker_label.show()
	_speaker_portrait.texture = NpcDatabase.portrait_of(npc_id)
	_speaker_portrait.show()
	_show_text(text)


func _show_text(text: String) -> void:
	_dialog_label.text = text
	_dialog_panel.show()
	_notice_left = NOTICE_SECONDS


func _on_prompt_changed(text: String) -> void:
	_prompt_label.text = "E: %s" % text if not text.is_empty() else ""


func _on_ticket_accepted(_ticket: TicketData) -> void:
	_ticket_panel.show()
