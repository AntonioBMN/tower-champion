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
	var minimap := floor_scene.get_node("UI/MinimapPanel/Minimap")
	var initial_visited_rooms: Dictionary = minimap.get("visited_rooms")
	_expect(initial_visited_rooms.size() == 1, "minimap should start with one room")
	_expect(minimap.get("current_room_index") == 0, "minimap should highlight start")
	_expect(
		minimap.call("get_current_room_draw_position").distance_to(
			minimap.size * 0.5
		) < 0.1,
		"current minimap room should start centered"
	)
	_expect(
		is_equal_approx(minimap.call("_calculate_draw_scale"), 1.0),
		"minimap should keep a fixed zoom as the graph expands"
	)
	var initial_connections: Array = floor_scene.get("room_connections")
	var generated_room_cells: Array = floor_scene.get("room_cells")
	var generated_room_bounds: Array = floor_scene.get("room_bounds")
	for room_index in range(room_count):
		_expect(
			minimap.call("get_room_shape_cell_count", room_index)
			== generated_room_cells[room_index].size(),
			"minimap should receive every exact generated room shape"
		)
	_expect(
		generated_room_cells[2].size()
		< generated_room_bounds[2].size.x * generated_room_bounds[2].size.y,
		"L-shaped room should preserve its cutout"
	)
	_expect(
		generated_room_cells[3].size()
		< generated_room_bounds[3].size.x * generated_room_bounds[3].size.y,
		"cross-shaped room should preserve its cutouts"
	)
	_expect(
		minimap.call("get_visible_enemy_marker_count") == 0,
		"starting room should be safe and have no enemy markers"
	)
	_expect(
		minimap.call("get_current_room_obstacle_marker_count") >= 1,
		"minimap should show neutral obstacle markers"
	)
	_expect(
		minimap.call("get_visible_door_count", 0)
		== initial_connections[0].size(),
		"minimap should show every door in the starting room"
	)
	var ranged_test_room: int = floor_scene.get("final_room_index")
	floor_scene.call("_spawn_room_enemies", ranged_test_room)

	var has_ranged_enemy := false

	for enemy in floor_scene.get_node("Enemies").get_children():
		var enemy_script := enemy.get_script() as Script

		if (
			enemy_script != null
			and enemy_script.resource_path == "res://ranged_enemy.gd"
		):
			has_ranged_enemy = true
			break

	_expect(has_ranged_enemy, "final room should include a ranged enemy")

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
			and first_door_collision.disabled,
			"starting room doors should be open because it is safe"
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
		var visited_rooms: Dictionary = minimap.get("visited_rooms")
		_expect(visited_rooms.has(0), "minimap should retain previously visited room")
		_expect(visited_rooms.has(destination), "minimap should reveal destination")
		_expect(
			minimap.get("current_room_index") == destination,
			"minimap should highlight the current room"
		)
		_expect(
			minimap.call("get_current_room_draw_position").distance_to(
				minimap.size * 0.5
			) < 0.1,
			"current minimap room should remain centered after transition"
		)
		_expect(
			minimap.call("get_visible_door_count", destination)
			== connections[destination].size(),
			"minimap should show every door in the destination room"
		)

	if failures == 0:
		print("PASS: first floor room transition smoke test")

	quit(failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return

	failures += 1
	push_error("FAIL: " + message)
