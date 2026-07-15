extends SceneTree

const FIRST_FLOOR_SCENE: PackedScene = preload(
	"res://world/floors/first_floor.tscn"
)
const ROOM_SLIDE_TRANSITION = preload(
	"res://ui/transitions/room_slide_transition.gd"
)

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var floor_scene := FIRST_FLOOR_SCENE.instantiate()
	root.add_child(floor_scene)
	await process_frame
	var slide_test_size := Vector2(1152.0, 648.0)
	for slide_direction in [
		Vector2i.UP,
		Vector2i.DOWN,
		Vector2i.LEFT,
		Vector2i.RIGHT,
	]:
		_expect(
			ROOM_SLIDE_TRANSITION.calculate_slide_offset(
				slide_direction,
				slide_test_size
			) == Vector2(slide_direction) * slide_test_size,
			"room slide should enter from its connected door direction"
		)
	_expect(
		ROOM_SLIDE_TRANSITION.world_to_screen_position(
			Vector2(150.0, 80.0),
			Vector2(100.0, 50.0),
			Vector2(2.0, 2.0),
			slide_test_size
		) == slide_test_size * 0.5 + Vector2(100.0, 60.0),
		"transition player should preserve its camera-relative position"
	)
	var clear_color: Color = ProjectSettings.get_setting(
		"rendering/environment/defaults/default_clear_color"
	)
	_expect(
		clear_color.get_luminance() < 0.02,
		"world background should use the dark tower palette"
	)
	_expect(
		ROOM_SLIDE_TRANSITION.ENTERING_ROOM_INITIAL_TINT.get_luminance()
		< 0.35
		and ROOM_SLIDE_TRANSITION.DEPARTING_ROOM_FINAL_TINT.get_luminance()
		< ROOM_SLIDE_TRANSITION.ENTERING_ROOM_INITIAL_TINT.get_luminance(),
		"room slide should darken the departure and fade in the destination"
	)

	var room_count: int = floor_scene.get("generated_room_count")
	_expect(room_count >= 8 and room_count <= 12, "room count must be 8..12")
	var minimap := floor_scene.get_node("UI/MinimapPanel/Minimap")
	var floor_tiles := floor_scene.get_node("GeneratedMap/FloorTiles") as CanvasItem
	var wall_tiles := floor_scene.get_node("GeneratedMap/WallTiles") as CanvasItem
	_expect(
		floor_tiles.self_modulate.get_luminance() < 0.6
		and wall_tiles.self_modulate.get_luminance() < 0.75,
		"floor scenery should remain darker than gameplay actors"
	)
	var initial_visited_rooms: Dictionary = minimap.get("visited_rooms")
	var initial_discovered_rooms: Dictionary = minimap.get("discovered_rooms")
	_expect(initial_visited_rooms.size() == 1, "minimap should start with one room")
	_expect(
		initial_discovered_rooms.size() == 1,
		"minimap should hide neighboring rooms until they are entered"
	)
	_expect(minimap.get("current_room_index") == 0, "minimap should highlight start")
	var player := floor_scene.get_node("Player") as CharacterBody2D
	var camera := player.get_node("Camera2D") as Camera2D
	var initial_player_position := player.global_position
	var initial_camera_center := camera.get_screen_center_position()
	player.global_position += Vector2(64.0, 0.0)
	await physics_frame
	await process_frame
	_expect(
		camera.get_screen_center_position().distance_to(initial_camera_center) < 0.1,
		"camera should remain fixed while moving inside a regular room"
	)
	player.global_position = initial_player_position
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
	var generated_door_cells: Array = floor_scene.get("room_door_cells")
	var generated_door_ratios: Array = floor_scene.get("room_door_ratios")
	var room_positions: Array = floor_scene.get("room_grid_positions")
	var generated_room_cells: Array = floor_scene.get("room_cells")
	var generated_room_bounds: Array = floor_scene.get("room_bounds")
	var large_room_indices: Dictionary = floor_scene.get("large_room_indices")
	var screen_room_size: Vector2i = floor_scene.call("_screen_room_size")
	var viewport_size: Vector2 = floor_scene.get_viewport_rect().size
	var dead_end_count := 0
	var decentralized_door_count := 0
	for room_index in range(room_count):
		if room_index > 0 and initial_connections[room_index].size() == 1:
			dead_end_count += 1
		for direction in initial_connections[room_index]:
			var destination: int = initial_connections[room_index][direction]
			_expect(
				room_positions[destination] - room_positions[room_index]
				== direction,
				"connected rooms should occupy adjacent grid cells"
			)
			var room_door_position: Vector2 = minimap.call(
				"get_room_door_layout_position",
				room_index,
				direction
			)
			var destination_door_position: Vector2 = minimap.call(
				"get_room_door_layout_position",
				destination,
				-direction
			)
			_expect(
				room_door_position.distance_to(destination_door_position) < 0.01,
				"both minimap door markers should meet at the same position"
			)

			var room_map_rect: Rect2 = minimap.call(
				"get_room_layout_rect", room_index
			)
			var tangent_ratio: float = generated_door_ratios[
				room_index
			][direction]
			var expected_door_position := room_map_rect.position
			if direction.x != 0:
				expected_door_position.x = (
					room_map_rect.end.x
					if direction.x > 0
					else room_map_rect.position.x
				)
				expected_door_position.y += (
					room_map_rect.size.y * tangent_ratio
				)
			else:
				expected_door_position.y = (
					room_map_rect.end.y
					if direction.y > 0
					else room_map_rect.position.y
				)
				expected_door_position.x += (
					room_map_rect.size.x * tangent_ratio
				)
			_expect(
				room_door_position.distance_to(expected_door_position) < 0.01,
				"minimap doors should reflect their generated wall position"
			)

			var room_bounds: Rect2i = generated_room_bounds[room_index]
			var door_cell: Vector2i = generated_door_cells[
				room_index
			][direction]
			var physical_ratio := (
				float(door_cell.y - room_bounds.position.y) + 0.5
			) / room_bounds.size.y
			if direction.y != 0:
				physical_ratio = (
					float(door_cell.x - room_bounds.position.x) + 0.5
				) / room_bounds.size.x
			_expect(
				absf(physical_ratio - tangent_ratio) < 0.0001,
				"physical doors should follow their minimap wall position"
			)
			if absf(tangent_ratio - 0.5) >= 0.08:
				decentralized_door_count += 1
	_expect(
		decentralized_door_count >= room_count - 1,
		"floor generation should create visibly decentralized doors"
	)
	_expect(
		dead_end_count >= 4,
		"floor graph should provide at least four useful dead ends"
	)
	_expect(
		floor_scene.call("_connection_count") == room_count - 1,
		"floor layout should use a clear branching tree structure"
	)
	_expect(
		large_room_indices.size() >= 1 and large_room_indices.size() <= 2,
		"each floor should contain only one or two large rooms"
	)
	for room_index in range(room_count):
		_expect(
			minimap.call("get_room_shape_cell_count", room_index)
			== generated_room_cells[room_index].size(),
			"minimap should receive every exact generated room shape"
		)
		var room_size: Vector2i = generated_room_bounds[room_index].size
		_expect(
			generated_room_cells[room_index].size()
			== room_size.x * room_size.y,
			"every generated room should be a complete rectangle"
		)
		if large_room_indices.has(room_index):
			var footprint_size: Vector2i = minimap.call(
				"get_room_footprint_size", room_index
			)
			_expect(
				footprint_size.x > 1 or footprint_size.y > 1,
				"large rooms should occupy multiple cells on the minimap"
			)
			var expected_room_size := screen_room_size * footprint_size
			_expect(
				room_size == expected_room_size,
				"large physical rooms should match their minimap footprint"
			)
		else:
			_expect(
				room_size == screen_room_size,
				"regular rooms should fit within one visible screen"
			)
			var camera_bounds_size := Vector2(
				(room_size + Vector2i(2, 2)) * 64
			)
			_expect(
				camera_bounds_size.x <= viewport_size.x
				and camera_bounds_size.y <= viewport_size.y,
				"regular room camera limits should not require tracking"
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
	var start_map_rect: Rect2 = minimap.call("get_room_layout_rect", 0)
	for direction in initial_connections[0]:
		var destination: int = initial_connections[0][direction]
		var destination_map_rect: Rect2 = minimap.call(
			"get_room_layout_rect", destination
		)
		var rooms_touch := false
		if direction.x > 0:
			rooms_touch = is_equal_approx(
				start_map_rect.end.x,
				destination_map_rect.position.x
			)
		elif direction.x < 0:
			rooms_touch = is_equal_approx(
				start_map_rect.position.x,
				destination_map_rect.end.x
			)
		elif direction.y > 0:
			rooms_touch = is_equal_approx(
				start_map_rect.end.y,
				destination_map_rect.position.y
			)
		else:
			rooms_touch = is_equal_approx(
				start_map_rect.position.y,
				destination_map_rect.end.y
			)
		_expect(
			rooms_touch,
			"connected minimap rooms should share a border without connector lines"
		)
		var hidden_destination_rect: Rect2 = minimap.call(
			"get_room_display_rect", destination
		)
		_expect(
			hidden_destination_rect.size == Vector2.ZERO,
			"unvisited neighboring rooms should not be rendered"
		)
	var ranged_test_room: int = floor_scene.get("final_room_index")
	_expect(
		floor_scene.get("room_encounters")[ranged_test_room].has("ranged"),
		"final encounter composition should include ranged enemies"
	)

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
		_expect(
			floor_scene.get("last_transition_direction") == direction,
			"room transition should preserve the door travel direction"
		)
		_expect(
			not floor_scene.get("is_transitioning")
			and not floor_scene.get_node("UI/TransitionFade").visible,
			"room transition should restore gameplay without a black overlay"
		)
		_expect(
			player.visible
			and floor_scene.get("active_transition_overlay") == null,
			"room transition should restore one visible player"
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
			minimap.call("get_discovered_room_count") == 2,
			"entering one room should not reveal any of its other neighbors"
		)
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
