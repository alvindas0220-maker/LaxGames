class_name HUD
extends CanvasLayer
## Muestra la carrera del jugador: amonestaciones, reputación, ticket y avisos.

## Alto lógico de la interfaz: se escala a múltiplos enteros para mantener el píxel.
const BASE_HEIGHT := 216
const NOTICE_SECONDS := 5.0

@export var player: Node2D
@export var world_layer: TileMapLayer
@export var warning_on: Texture2D
@export var warning_off: Texture2D

var _notice_left := 0.0

@onready var _root: Control = $Root
@onready var _warnings: HBoxContainer = %Warnings
@onready var _reputation_bar: TextureProgressBar = %ReputationBar
@onready var _reputation_label: Label = %ReputationLabel
@onready var _career_label: Label = %CareerLabel
@onready var _day_label: Label = %DayLabel
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
	_prompt_label.text = ""
	GameState.warnings_changed.connect(_on_warnings_changed)
	GameState.reputation_changed.connect(_on_reputation_changed)
	GameState.stage_changed.connect(_on_stage_changed)
	GameState.notice.connect(_on_notice)
	DialogueManager.line_shown.connect(_on_line_shown)
	GameState.prompt_changed.connect(_on_prompt_changed)
	TicketManager.ticket_accepted.connect(_on_ticket_accepted)
	TicketManager.ticket_closed.connect(_ticket_panel.hide)
	_on_warnings_changed(GameState.warnings)
	_on_reputation_changed(GameState.reputation)
	_on_stage_changed(GameState.stage_title())


func _process(delta: float) -> void:
	_day_label.text = "%s  Tickets %d/%d" % [WorkdayManager.label(), WorkdayManager.closed_today, WorkdayManager.quota()]
	if _dialog_panel.visible:
		_notice_left -= delta
		if _notice_left <= 0.0:
			_dialog_panel.hide()
	if TicketManager.active != null:
		var ticket := TicketManager.active
		var progress := " %d/%d" % [TicketManager.repairs_done, ticket.repairs] if ticket.repairs > 1 else ""
		_ticket_label.text = "[%s] %s%s  %ds" % [TicketManager.priority(), ticket.title, progress, ceili(TicketManager.time_left)]


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


func _on_reputation_changed(value: int) -> void:
	_reputation_bar.max_value = GameState.MAX_REPUTATION
	_reputation_bar.value = value
	_reputation_label.text = "%d%%" % value


func _on_stage_changed(title: String) -> void:
	_career_label.text = title


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
