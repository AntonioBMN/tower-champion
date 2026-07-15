extends SceneTree

const FIRST_FLOOR_SCENE: PackedScene = preload(
	"res://world/floors/first_floor.tscn"
)
const SEED_SAMPLE_COUNT := 20

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for seed_offset in range(SEED_SAMPLE_COUNT):
		var floor_scene := FIRST_FLOOR_SCENE.instantiate()
		floor_scene.set("randomize_layout", false)
		floor_scene.set("fixed_seed", 41000 + seed_offset)
		root.add_child(floor_scene)
		await process_frame
		_validate_layout(floor_scene, 41000 + seed_offset)
		floor_scene.queue_free()
		await process_frame

	if failures == 0:
		print("PASS: Isaac-style floor layout generation smoke test")

	quit(failures)


func _validate_layout(floor_scene: Node, seed_value: int) -> void:
	var room_count: int = floor_scene.get("generated_room_count")
	var positions: Array = floor_scene.get("room_grid_positions")
	var connections: Array = floor_scene.get("room_connections")
	var door_cells: Array = floor_scene.get("room_door_cells")
	var door_ratios: Array = floor_scene.get("room_door_ratios")
	var room_bounds: Array = floor_scene.get("room_bounds")
	var room_types: Array = floor_scene.get("room_types")
	var room_distances: Array = floor_scene.get("room_distances")
	var final_room_index: int = floor_scene.get("final_room_index")
	var special_room_index: int = floor_scene.get("special_room_index")
	var treasure_room_index: int = floor_scene.get("treasure_room_index")
	var large_rooms: Dictionary = floor_scene.get("large_room_indices")
	var footprints: Dictionary = floor_scene.get("large_room_footprints")
	var screen_room_size: Vector2i = floor_scene.call("_screen_room_size")
	var door_entries: Array = floor_scene.get("door_entries")
	var occupied: Dictionary = {}
	var minimap := floor_scene.get_node("UI/SafeFrame/MinimapPanel/Minimap")

	_expect(
		room_count >= 8 and room_count <= 12,
		"seed %d should generate 8..12 rooms" % seed_value
	)
	_expect(
		floor_scene.call("_connection_count") == room_count - 1,
		"seed %d should generate one connected branching tree" % seed_value
	)
	_expect(
		room_distances.max() >= 3
		and room_distances[final_room_index] == room_distances.max(),
		"seed %d should keep the final room on a distant branch" % seed_value
	)

	var dead_end_count := 0
	var decentralized_door_count := 0
	for room_index in range(room_count):
		var position: Vector2i = positions[room_index]
		_expect(
			not occupied.has(position),
			"seed %d should not overlap logical rooms" % seed_value
		)
		occupied[position] = room_index
		if room_index > 0 and connections[room_index].size() == 1:
			dead_end_count += 1
		for direction in connections[room_index]:
			var destination: int = connections[room_index][direction]
			_expect(
				positions[destination] - position == direction,
				"seed %d should connect only adjacent grid rooms" % seed_value
			)
			var room_door_position: Vector2 = minimap.call(
				"get_room_door_layout_position", room_index, direction
			)
			var destination_door_position: Vector2 = minimap.call(
				"get_room_door_layout_position", destination, -direction
			)
			_expect(
				room_door_position.distance_to(destination_door_position) < 0.01,
				"seed %d minimap doors should align exactly" % seed_value
			)
			var tangent_ratio: float = door_ratios[room_index][direction]
			var bounds: Rect2i = room_bounds[room_index]
			var door_cell: Vector2i = door_cells[room_index][direction]
			var physical_ratio := (
				float(door_cell.y - bounds.position.y) + 0.5
			) / bounds.size.y
			if direction.y != 0:
				physical_ratio = (
					float(door_cell.x - bounds.position.x) + 0.5
				) / bounds.size.x
			_expect(
				absf(physical_ratio - tangent_ratio) < 0.0001,
				"seed %d physical and minimap doors should agree" % seed_value
			)
			if absf(tangent_ratio - 0.5) >= 0.08:
				decentralized_door_count += 1

			var room_footprint_size := Vector2i.ONE
			var room_footprint_position := Vector2i.ZERO
			if footprints.has(room_index):
				var room_footprint: Rect2i = footprints[room_index]
				room_footprint_size = room_footprint.size
				room_footprint_position = room_footprint.position
			var destination_footprint_size := Vector2i.ONE
			var destination_footprint_position := Vector2i.ZERO
			if footprints.has(destination):
				var destination_footprint: Rect2i = footprints[destination]
				destination_footprint_size = destination_footprint.size
				destination_footprint_position = destination_footprint.position
			var room_cells_per_map_cell := (
				float(bounds.size.x) / room_footprint_size.x
				if direction.y != 0
				else float(bounds.size.y) / room_footprint_size.y
			)
			var destination_bounds: Rect2i = room_bounds[destination]
			var destination_cells_per_map_cell := (
				float(destination_bounds.size.x)
				/ destination_footprint_size.x
				if direction.y != 0
				else float(destination_bounds.size.y)
				/ destination_footprint_size.y
			)
			_expect(
				absf(
					room_cells_per_map_cell
					- destination_cells_per_map_cell
				) < 0.001,
				"seed %d connected doors should share one physical tile scale"
				% seed_value
			)

			var destination_door_cell: Vector2i = door_cells[
				destination
			][-direction]
			var room_global_door_lane: int
			var destination_global_door_lane: int
			if direction.y != 0:
				room_global_door_lane = (
					(position.x + room_footprint_position.x)
					* screen_room_size.x
					+ door_cell.x - bounds.position.x
				)
				destination_global_door_lane = (
					(
						positions[destination].x
						+ destination_footprint_position.x
					) * screen_room_size.x
					+ destination_door_cell.x
					- destination_bounds.position.x
				)
			else:
				room_global_door_lane = (
					(position.y + room_footprint_position.y)
					* screen_room_size.y
					+ door_cell.y - bounds.position.y
				)
				destination_global_door_lane = (
					(
						positions[destination].y
						+ destination_footprint_position.y
					) * screen_room_size.y
					+ destination_door_cell.y
					- destination_bounds.position.y
				)
			_expect(
				room_global_door_lane == destination_global_door_lane,
				"seed %d both door sides should use the exact same tile lane"
				% seed_value
			)

	_expect(
		decentralized_door_count >= room_count - 1,
		"seed %d should include visibly decentralized doors" % seed_value
	)

	for room_index in range(room_count):
		var room_rect: Rect2 = minimap.call(
			"get_room_layout_rect", room_index
		).grow(-0.1)
		for other_index in range(room_index + 1, room_count):
			var other_rect: Rect2 = minimap.call(
				"get_room_layout_rect", other_index
			).grow(-0.1)
			_expect(
				not room_rect.intersects(other_rect),
				"seed %d minimap rooms %d and %d should not overlap (%s / %s)"
				% [seed_value, room_index, other_index, room_rect, other_rect]
			)

	_expect(
		dead_end_count >= 4,
		"seed %d should generate at least four dead ends" % seed_value
	)
	for special_index in [
		final_room_index,
		special_room_index,
		treasure_room_index,
	]:
		_expect(
			connections[special_index].size() == 1,
			"seed %d should place special rooms on dead ends" % seed_value
		)
	_expect(
		room_types[final_room_index] == "final",
		"seed %d should retain the final room role" % seed_value
	)
	var final_gate_direction: Vector2i = connections[
		final_room_index
	].keys()[0]
	var final_gate_cell: Vector2i = door_cells[
		final_room_index
	][final_gate_direction]
	var final_gate_tangent := Vector2i(
		-final_gate_direction.y,
		final_gate_direction.x
	)
	for offset in range(-1, 2):
		var opening_cell := final_gate_cell + final_gate_tangent * offset
		_expect(
			floor_scene.call(
				"_is_open_edge",
				opening_cell,
				final_gate_direction
			),
			"seed %d final-room gate should open three wall cells"
			% seed_value
		)
	var final_gate_entry_count := 0
	for entry in door_entries:
		if entry["is_final_gate"]:
			final_gate_entry_count += 1
	_expect(
		final_gate_entry_count == 2,
		"seed %d should build the large gate on both sides of the final link"
		% seed_value
	)

	_expect(
		large_rooms.size() >= 1 and large_rooms.size() <= 2,
		"seed %d should generate one or two large rooms" % seed_value
	)
	var reserved_footprint_cells: Dictionary = {}
	for room_index in footprints:
		var footprint: Rect2i = footprints[room_index]
		_expect(
			footprint.size.x > 1 or footprint.size.y > 1,
			"seed %d large rooms should occupy multiple map cells" % seed_value
		)
		var anchor: Vector2i = positions[room_index]
		for y in range(footprint.size.y):
			for x in range(footprint.size.x):
				var footprint_cell := (
					anchor + footprint.position + Vector2i(x, y)
				)
				if footprint_cell == anchor:
					continue
				_expect(
					not occupied.has(footprint_cell)
					and not reserved_footprint_cells.has(footprint_cell),
					"seed %d large map footprints should not overlap" % seed_value
				)
				reserved_footprint_cells[footprint_cell] = true

	_expect(
		minimap.call("get_discovered_room_count") == 1,
		"seed %d should hide every unvisited room" % seed_value
	)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return

	failures += 1
	push_error("FAIL: " + message)
