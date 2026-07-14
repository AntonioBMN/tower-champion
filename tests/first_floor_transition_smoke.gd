extends SceneTree

const FIRST_FLOOR_SCENE: PackedScene = preload("res://first_floor.tscn")

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var floor_scene := FIRST_FLOOR_SCENE.instantiate()
	root.add_child(floor_scene)
	await process_frame

	var room_count: int = floor_scene.get("generated_room_count")
	_expect(room_count >= 5 and room_count <= 8, "room count must be 5..8")

	var connections: Array = floor_scene.get("room_connections")
	var first_room_connections: Dictionary = connections[0]
	_expect(not first_room_connections.is_empty(), "starting room needs a door")

	if not first_room_connections.is_empty():
		var direction: Vector2i = first_room_connections.keys()[0]
		var destination: int = first_room_connections[direction]
		var first_door_collision: CollisionShape2D

		for entry in floor_scene.get("door_entries"):
			if entry["room"] == 0:
				first_door_collision = entry["collision"] as CollisionShape2D
				break

		_expect(
			is_instance_valid(first_door_collision)
			and not first_door_collision.disabled,
			"doors should start locked while enemies are alive"
		)

		var room_enemy_counts: Array = floor_scene.get("room_enemies_remaining")
		room_enemy_counts[0] = 0
		floor_scene.call("_refresh_room_doors", 0)
		await physics_frame
		_expect(
			first_door_collision.disabled,
			"doors should open when the room is clear"
		)

		var player := floor_scene.get_node("Player") as CharacterBody2D
		floor_scene.call(
			"_on_door_body_entered",
			player,
			0,
			destination,
			direction
		)
		await create_timer(0.7).timeout

		_expect(
			floor_scene.get("current_room_index") == destination,
			"door should transition to its connected room"
		)
		var spawned_rooms: Dictionary = floor_scene.get("spawned_rooms")
		_expect(
			spawned_rooms.has(destination),
			"destination room should activate its enemy spawns"
		)

	if failures == 0:
		print("PASS: first floor room transition smoke test")

	quit(failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return

	failures += 1
	push_error("FAIL: " + message)
