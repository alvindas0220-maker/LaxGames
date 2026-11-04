class_name Player
extends CharacterBody2D
## Jugador con movimiento top-down en 8 direcciones.

const DIRECTION_STEP := PI / 4.0

## Velocidad máxima en píxeles por segundo.
@export_range(0.0, 500.0, 1.0) var max_speed := 120.0
## Píxeles/s² ganados al arrancar o cambiar de dirección.
@export_range(0.0, 5000.0, 10.0) var acceleration := 1200.0
## Píxeles/s² perdidos al soltar el movimiento.
@export_range(0.0, 5000.0, 10.0) var friction := 1600.0


func _physics_process(delta: float) -> void:
	var direction := _get_input_direction()

	# Sin entrada y parado no hay nada que calcular ni colisiones que resolver.
	if direction == Vector2.ZERO and velocity == Vector2.ZERO:
		return

	var rate := friction if direction == Vector2.ZERO else acceleration
	velocity = velocity.move_toward(direction * max_speed, rate * delta)
	move_and_slide()


## Devuelve un vector unitario limitado a 8 direcciones, o cero sin entrada.
## get_vector() ya normaliza las diagonales; el ajuste limita también al stick.
func _get_input_direction() -> Vector2:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input == Vector2.ZERO:
		return Vector2.ZERO
	return Vector2.from_angle(snappedf(input.angle(), DIRECTION_STEP))
