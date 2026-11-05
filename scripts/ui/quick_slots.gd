class_name QuickSlots
extends PanelContainer
## Selección rápida de herramientas: slot_1, slot_2... eligen cada casilla.

signal slot_selected(index: int)

var selected := 0

@onready var _slots: Array[Node] = $Slots.get_children()


func _ready() -> void:
	ToolBelt.changed.connect(_refresh)
	select(ToolBelt.selected)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	for i in _slots.size():
		if event.is_action_pressed("slot_%d" % (i + 1)):
			select(i)
			get_viewport().set_input_as_handled()
			return


func select(index: int) -> void:
	selected = index
	ToolBelt.selected = index as ToolBelt.Tool
	for i in _slots.size():
		_slots[i].set_selected(i == index)
	slot_selected.emit(index)


func _refresh() -> void:
	_slots[ToolBelt.Tool.COFFEE].set_count(ToolBelt.coffee)
