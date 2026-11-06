class_name RepairAction
extends RefCounted
## Maniobra concreta de una avería. RepairBar la conduce: le pasa el tiempo, el
## teclado y un lienzo donde dibujarse, y escucha cuándo termina.

signal finished(success: bool)

const INK := Color8(26, 20, 32)
const TRACK := Color8(60, 70, 86)
const GOOD := Color8(80, 224, 128)
const BAD := Color8(232, 72, 60)
const LIGHT := Color8(248, 216, 120)

## Instrucción para el jugador; puede cambiar durante la maniobra.
var hint := ""


func begin(_param: Variant, _speed: float) -> void:
	pass


func tick(_delta: float) -> void:
	pass


## Devuelve true si la maniobra usó esa pulsación.
func handle(_event: InputEvent) -> bool:
	return false


func paint(_canvas: Control, _size: Vector2) -> void:
	pass
