class_name OverhearZone
extends Area2D
## Zona de pasillo donde el protagonista escucha conversaciones al pasar.

@export var zone := ""


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		Overheard.overhear(zone)
