extends Node2D

var remaining_enemies: int = 0
var room_is_cleared: bool = false

@onready var enemy_counter_label: Label = (
	$UI/EnemyCounterLabel
)

@onready var room_cleared_label: Label = (
	$UI/RoomClearedLabel
)


func _ready() -> void:
	$UI/RoomClearedLabel.text = tr("TEST_ROOM_CLEARED")
	$UI/ControlsLabel.text = tr("TEST_ROOM_CONTROLS")
	$Player.global_position = $PlayerSpawn.global_position
	room_cleared_label.hide()
	register_enemies()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene"):
		get_viewport().set_input_as_handled()
		get_tree().reload_current_scene()


func register_enemies() -> void:
	var enemy_nodes := get_tree().get_nodes_in_group("enemies")

	remaining_enemies = enemy_nodes.size()

	for node in enemy_nodes:
		var enemy := node as Enemy

		if enemy != null:
			enemy.died.connect(_on_enemy_died)

	update_enemy_counter()

	if remaining_enemies == 0:
		complete_room()


func _on_enemy_died() -> void:
	remaining_enemies -= 1
	remaining_enemies = maxi(remaining_enemies, 0)

	update_enemy_counter()

	if remaining_enemies == 0:
		complete_room()


func update_enemy_counter() -> void:
	enemy_counter_label.text = tr("HUD_ENEMY_COUNT") % remaining_enemies


func complete_room() -> void:
	if room_is_cleared:
		return

	room_is_cleared = true

	print("Room cleared.")

	room_cleared_label.modulate = Color(
		1.0,
		1.0,
		1.0,
		0.0
	)

	room_cleared_label.show()

	var tween := create_tween()

	tween.tween_property(
		room_cleared_label,
		"modulate:a",
		1.0,
		0.3
	)

	tween.tween_interval(1.5)

	tween.tween_property(
		room_cleared_label,
		"modulate:a",
		0.0,
		0.5
	)
