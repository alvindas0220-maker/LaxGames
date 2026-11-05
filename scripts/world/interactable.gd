class_name Interactable
extends Area2D
## Algo con lo que el jugador puede interactuar al acercarse.

signal interacted

@export var prompt := "Interactuar"


func interact() -> void:
	interacted.emit()
