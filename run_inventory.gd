class_name RunInventory
extends Node

signal keys_changed(current_keys: int)

@export_range(0, 99, 1) var starting_keys: int = 0

var keys: int = 0


func _ready() -> void:
	keys = starting_keys
	keys_changed.emit(keys)


func add_keys(amount: int = 1) -> bool:
	if amount <= 0:
		return false

	keys = mini(keys + amount, 99)
	keys_changed.emit(keys)
	return true


func spend_key() -> bool:
	if keys <= 0:
		return false

	keys -= 1
	keys_changed.emit(keys)
	return true
