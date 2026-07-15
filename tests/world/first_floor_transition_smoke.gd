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
	floor_scene.set("randomize_layout", false)
	floor_scene.set("fixed_seed", 41007)
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
	var departure_anchor := Vector2(1088.0, 176.0)
	var destination_anchor := Vector2(64.0, 304.0)
	var anchor_slide_offset: Vector2 = (
		ROOM_SLIDE_TRANSITION.calculate_anchor_slide_offset(
			departure_anchor,
			destination_anchor
		)
	)
	_expect(
		destination_anchor + anchor_slide_offset == departure_anchor,
		"room slide should align differently positioned door anchors"
	)
	var departure_player := departure_anchor + Vector2(0.0, -50.0)
	var destination_player := destination_anchor + Vector2(0.0, -50.0)
	_expect(
		destination_player + anchor_slide_offset == departure_player,
		"player should remain attached to the aligned doorway lane"
	)
	_expect(
		ROOM_SLIDE_TRANSITION.calculate_anchor_slide_offset(
			destination_anchor,
			departure_anchor
		) == -anchor_slide_offset,
		"door anchor alignment should remain symmetric in reverse"
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
	var minimap := floor_scene.get_node("UI/SafeFrame/MinimapPanel/Minimap")
	var floor_tiles := floor_scene.get_node("GeneratedMap/FloorTiles") as TileMapLayer
	var wall_tiles := floor_scene.get_node("GeneratedMap/WallTiles") as CanvasItem
	var wall_decorations := floor_scene.get_node("GeneratedMap/WallDecorations")
	var door_sprites := floor_scene.get_node("GeneratedMap/Doors").find_children(
		"*",
		"Sprite2D",
		true,
		false
	)
	_expect(
		floor_tiles.self_modulate.get_luminance() < 0.6
		and wall_tiles.self_modulate.get_luminance() < 0.75,
		"floor scenery should remain darker than gameplay actors"
	)
	for floor_cell in floor_tiles.get_used_cells():
		var floor_atlas_coordinates := floor_tiles.get_cell_atlas_coords(
			floor_cell
		)
		_expect(
			floor_atlas_coordinates in [Vector2i(5, 1), Vector2i(9, 11)],
			"floor variation should use tiles, never the grate obstacle"
		)
	_expect(
		wall_decorations.get_child_count() > 0,
		"room walls should use the composed Pixel Crawler border"
	)
	var expected_door_sprite_count := 0
	for entry in floor_scene.get("door_entries"):
		expected_door_sprite_count += (1 if entry["is_final_gate"] else 2)
	_expect(
		door_sprites.size() >= expected_door_sprite_count,
		"common doors should use a frame and panel while the final gate stays whole"
	)
	var door_directions: Dictionary = {}
	var expected_top_cap_count := 0
	for entry in floor_scene.get("door_entries"):
		var direction: Vector2i = entry["direction"]
		var physical_center: Vector2 = entry["physical_center"]
		var visual := entry["visual"] as Node2D
		door_directions[direction] = true
		_expect(
			visual.position == floor_scene.call(
				"_door_visual_anchor",
				physical_center,
				direction
			),
			"door artwork should anchor to the interior wall face"
		)
		for child in visual.get_children():
			if child is not Sprite2D:
				continue
			var sprite := child as Sprite2D
			var atlas_texture := sprite.texture as AtlasTexture
			_expect(
				is_instance_valid(atlas_texture)
				and is_zero_approx(
					sprite.position.y
					+ atlas_texture.region.size.y * sprite.scale.y * 0.5
				),
				"door artwork should use the threshold pivot"
			)
		if direction == Vector2i.UP:
			expected_top_cap_count += (3 if entry["is_final_gate"] else 1)
	_expect(
		door_directions.size() == 4,
		"generated door artwork should preserve alignment in all four directions"
	)
	var top_cap_count := 0
	for decoration in wall_decorations.get_children():
		if String(decoration.name).begins_with("TopDoorCap_"):
			top_cap_count += 1
	_expect(
		top_cap_count == expected_top_cap_count,
		"upper door frames should connect to the full wall depth"
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
	var player_collision := player.get_node("CollisionShape2D") as CollisionShape2D
	var player_shape := player_collision.shape as CircleShape2D
	var player_sprite := player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var player_shadow := player.get_node("GroundShadow") as Polygon2D
	var vision_light := player.get_node("VisionLight") as PointLight2D
	_expect(
		is_instance_valid(player_shape) and player_shape.radius >= 18.0,
		"player should use a broad foot-level collision footprint"
	)
	_expect(
		player_sprite.position.y < 0.0
		and player_collision.position.y > player_sprite.position.y,
		"player artwork should be anchored above the physical footprint"
	)
	_expect(
		is_instance_valid(player_shadow) and player_shadow.z_index < 0,
		"player should cast a small ground shadow below the sprite"
	)
	_expect(
		is_instance_valid(vision_light)
		and vision_light.energy > 0.0
		and vision_light.energy <= 0.25
		and vision_light.range_z_max < 0,
		"player vision light should subtly affect scenery without washing out actors"
	)
	var start_bounds: Rect2i = floor_scene.get("room_bounds")[0]
	var solid_top_cell := Vector2i(start_bounds.position.x, start_bounds.position.y)
	for x in range(start_bounds.position.x, start_bounds.end.x):
		var candidate := Vector2i(x, start_bounds.position.y)
		if not floor_scene.call("_is_open_edge", candidate, Vector2i.UP):
			solid_top_cell = candidate
			break
	var wall_boundary_y := solid_top_cell.y * 64.0
	player.global_position = Vector2(
		(solid_top_cell.x + 0.5) * 64.0,
		wall_boundary_y + player_shape.radius + 4.0 - player_collision.position.y
	)
	await physics_frame
	var wall_hit := player.move_and_collide(Vector2(0.0, -64.0))
	_expect(
		wall_hit != null
		and wall_hit.get_collider() == floor_scene.get_node("GeneratedMap/Walls")
		and player.global_position.y + player_collision.position.y
		>= wall_boundary_y + player_shape.radius - 0.5,
		"player footprint should stop cleanly at room walls"
	)
	var obstacle_rects: Array = floor_scene.get("obstacle_rects")
	if not obstacle_rects.is_empty():
		var obstacle_rect: Rect2i = obstacle_rects[0]
		var obstacle_left := obstacle_rect.position.x * 64.0
		var obstacle_center_y := (
			obstacle_rect.position.y + obstacle_rect.size.y * 0.5
		) * 64.0
		player.global_position = Vector2(
			obstacle_left - player_shape.radius - 4.0,
			obstacle_center_y - player_collision.position.y
		)
		await physics_frame
		var obstacle_hit := player.move_and_collide(Vector2(64.0, 0.0))
		_expect(
			obstacle_hit != null
			and obstacle_hit.get_collider()
			== floor_scene.get_node("GeneratedMap/Obstacles"),
			"player footprint should stop cleanly at scenery obstacles"
		)
	player.global_position = initial_player_position
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
				(room_size + Vector2i(2, 3)) * 64
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
		for candidate_direction in first_room_connections:
			var candidate_destination: int = first_room_connections[
				candidate_direction
			]
			if large_room_indices.has(candidate_destination):
				direction = candidate_direction
				destination = candidate_destination
				break
		_expect(
			not large_room_indices.has(0)
			and large_room_indices.has(destination),
			"transition regression seed should connect start to a large room"
		)
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
			and not floor_scene.get_node("UI/SafeFrame/TransitionFade").visible,
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

		var reverse_direction := -direction
		floor_scene.call("_transition_to_room", 0, reverse_direction)
		await create_timer(0.7).timeout
		_expect(
			floor_scene.get("current_room_index") == 0,
			"large-to-small transition should return to the original room"
		)
		var return_cell: Vector2i = generated_door_cells[0][direction]
		var expected_return_position: Vector2 = (
			floor_scene.call("_actor_position_for_cell", return_cell)
			+ Vector2(reverse_direction) * 64.0 * 1.15
		)
		_expect(
			player.global_position.distance_to(expected_return_position) < 0.01,
			"large-to-small transition should preserve the arrival lane"
		)
		_expect(
			player.visible
			and floor_scene.get("active_transition_overlay") == null,
			"reverse transition should restore one visible player"
		)

	if failures == 0:
		print("PASS: first floor room transition smoke test")

	quit(failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return

	failures += 1
	push_error("FAIL: " + message)
