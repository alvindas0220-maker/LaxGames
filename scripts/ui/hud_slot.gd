class_name HudSlot
extends PanelContainer
## Casilla de selección rápida: icono, tecla y cantidad opcional.

@export var icon: Texture2D
## Cantidad mostrada; 0 la oculta.
@export var count := 0
@export var key_text := ""
@export var normal_style: StyleBox
@export var selected_style: StyleBox

@onready var _icon: TextureRect = $Icon
@onready var _count_label: Label = $CountLabel
@onready var _key_label: Label = $KeyLabel


func _ready() -> void:
	_icon.texture = icon
	_key_label.text = key_text
	set_count(count)


func set_count(value: int) -> void:
	count = value
	_count_label.text = str(count)
	_count_label.visible = count > 0


func set_selected(selected: bool) -> void:
	add_theme_stylebox_override("panel", selected_style if selected else normal_style)
