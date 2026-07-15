class_name FloorMinimap
extends Control

signal exploration_changed(visited_count: int, total_count: int)

const ROOM_DISPLAY_SIZE := Vector2(40.0, 32.0)
const MARKER_REFRESH_INTERVAL := 0.05
const EXPANDED_MAP_PADDING := Vector2(42.0, 34.0)
const EXPANDED_MINIMUM_SCALE := 0.55
const EXPANDED_MAXIMUM_SCALE := 1.75
const VISITED_ROOM_COLOR := Color(0.3, 0.34, 0.43, 1.0)
const UNEXPLORED_ROOM_COLOR := Color(0.12, 0.14, 0.19, 0.82)
const CURRENT_ROOM_COLOR := Color(0.96, 0.68, 0.18, 1.0)
const ROOM_OUTLINE_COLOR := Color(0.018, 0.022, 0.03, 1.0)
const ROOM_BORDER_COLOR := Color(0.76, 0.79, 0.86, 1.0)
const UNEXPLORED_BORDER_COLOR := Color(0.38, 0.42, 0.5, 0.82)
const DOOR_COLOR := Color(0.86, 0.88, 0.94, 1.0)
const LOCKED_DOOR_COLOR := Color(0.95, 0.24, 0.2, 1.0)
const PLAYER_MARKER_COLOR := Color(0.2, 0.95, 0.72, 1.0)
const ENEMY_MARKER_COLOR := Color(0.95, 0.18, 0.16, 1.0)
const OBSTACLE_MARKER_COLOR := Color(0.64, 0.66, 0.7, 1.0)
const MARKER_BORDER_COLOR := Color(0.08, 0.09, 0.12, 0.95)
const FINAL_ROOM_COLOR := Color(0.52, 0.16, 0.18, 1.0)
const SPECIAL_ROOM_COLOR := Color(0.27, 0.2, 0.5, 1.0)
const TREASURE_ROOM_COLOR := Color(0.42, 0.3, 0.08, 1.0)
const START_MARKER_COLOR := Color(0.3, 0.72, 1.0, 1.0)
const FINAL_MARKER_COLOR := Color(1.0, 0.28, 0.24, 1.0)
const SPECIAL_MARKER_COLOR := Color(0.76, 0.5, 1.0, 1.0)
const TREASURE_MARKER_COLOR := Color(1.0, 0.76, 0.2, 1.0)
const EXIT_MARKER_COLOR := Color(0.28, 1.0, 0.7, 1.0)
const HEALTH_CONTENT_COLOR := Color(0.98, 0.2, 0.28, 1.0)
const KEY_CONTENT_COLOR := Color(1.0, 0.78, 0.18, 1.0)
const RELIC_CONTENT_COLOR := Color(0.75, 0.48, 1.0, 1.0)
const CHEST_CONTENT_COLOR := Color(0.9, 0.58, 0.2, 1.0)
const CONTENT_PRIORITY := ["relic", "chest", "key", "health"]

var room_positions: Array[Vector2i] = []
var room_connections: Array = []
var room_bounds: Array[Rect2i] = []
var room_cells: Array = []
var room_door_cells: Array = []
var room_types: Array[String] = []
var obstacle_rects: Array[Rect2i] = []
var tracked_player: Node2D
var tracked_enemies: Node
var world_cell_size: float = 1.0
var visited_rooms: Dictionary = {}
var discovered_rooms: Dictionary = {}
var current_room_index: int = -1
var exit_room_index: int = -1
var exit_available: bool = false
var marker_refresh_elapsed: float = 0.0
var expanded: bool = false
var locked_rooms: Dictionary = {}
var content_sources: Dictionary = {}
var large_room_footprints: Dictionary = {}
var room_door_ratios: Array = []
var map_room_centers: Array[Vector2] = []
var map_room_sizes: Array[Vector2] = []


func configure(
	positions: Array[Vector2i],
	connections: Array,
	bounds: Array[Rect2i],
	cells: Array,
	door_cells: Array,
	types: Array[String],
	obstacles_value: Array[Rect2i],
	player_value: Node2D,
	enemies_value: Node,
	world_cell_size_value: float,
	content_sources_value: Dictionary = {},
	large_room_footprints_value: Dictionary = {},
	door_ratios_value: Array = []
) -> void:
	room_positions.assign(positions)
	room_connections = connections.duplicate(true)
	room_bounds.assign(bounds)
	room_cells = cells.duplicate(true)
	room_door_cells = door_cells.duplicate(true)
	room_types.assign(types)
	obstacle_rects.assign(obstacles_value)
	tracked_player = player_value
	tracked_enemies = enemies_value
	world_cell_size = maxf(world_cell_size_value, 1.0)
	content_sources = content_sources_value.duplicate()
	large_room_footprints = large_room_footprints_value.duplicate(true)
	room_door_ratios = door_ratios_value.duplicate(true)
	_calculate_map_room_centers()
	visited_rooms.clear()
	discovered_rooms.clear()
	locked_rooms.clear()
	current_room_index = -1
	exit_room_index = -1
	exit_available = false
	queue_redraw()
	exploration_changed.emit(0, room_positions.size())


func _process(delta: float) -> void:
	if current_room_index < 0:
		return

	marker_refresh_elapsed += delta
	if marker_refresh_elapsed >= MARKER_REFRESH_INTERVAL:
		marker_refresh_elapsed = 0.0
		queue_redraw()


func visit_room(room_index: int) -> void:
	if room_index < 0 or room_index >= room_positions.size():
		return

	visited_rooms[room_index] = true
	discovered_rooms[room_index] = true
	current_room_index = room_index
	queue_redraw()
	exploration_changed.emit(visited_rooms.size(), room_positions.size())


func _draw() -> void:
	if visited_rooms.is_empty() or current_room_index < 0:
		return

	var draw_scale := _calculate_draw_scale()
	var map_origin := _calculate_map_origin(draw_scale)
	var drawn_rooms := _get_drawn_room_indices()

	for room_index in drawn_rooms:
		var center := _room_draw_position(room_index, map_origin, draw_scale)
		var room_color := _room_color(room_index)
		var border_color := (
			ROOM_BORDER_COLOR
			if visited_rooms.has(room_index)
			else UNEXPLORED_BORDER_COLOR
		)

		_draw_room_shape(
			room_index,
			center,
			draw_scale,
			room_color,
			border_color
		)
		_draw_room_doors(room_index, center, draw_scale)
		_draw_room_role_marker(room_index, center, draw_scale)
		if visited_rooms.has(room_index):
			_draw_room_contents(room_index, center, draw_scale)

	var current_room_center := _room_draw_position(
		current_room_index,
		map_origin,
		draw_scale
	)
	_draw_current_room_markers(current_room_center, draw_scale)


func _room_color(room_index: int) -> Color:
	if room_index == current_room_index:
		return CURRENT_ROOM_COLOR
	if not visited_rooms.has(room_index):
		return UNEXPLORED_ROOM_COLOR

	match room_types[room_index]:
		"final":
			return FINAL_ROOM_COLOR
		"special":
			return SPECIAL_ROOM_COLOR
		"treasure":
			return TREASURE_ROOM_COLOR
		_:
			return VISITED_ROOM_COLOR


func _draw_room_role_marker(
	room_index: int,
	room_center: Vector2,
	draw_scale: float
) -> void:
	if exit_available and room_index == exit_room_index:
		draw_circle(
			room_center,
			maxf(4.0, 5.0 * draw_scale),
			MARKER_BORDER_COLOR
		)
		draw_arc(
			room_center,
			maxf(3.0, 4.0 * draw_scale),
			0.0,
			TAU,
			20,
			EXIT_MARKER_COLOR,
			2.0,
			true
		)
		return

	match room_types[room_index]:
		"start":
			draw_circle(
				room_center,
				maxf(2.0, 2.5 * draw_scale),
				START_MARKER_COLOR
			)
		"special":
			var marker_size := maxf(4.0, 5.0 * draw_scale)
			draw_line(
				room_center - Vector2(marker_size, 0.0),
				room_center + Vector2(marker_size, 0.0),
				SPECIAL_MARKER_COLOR,
				2.0
			)
			draw_line(
				room_center - Vector2(0.0, marker_size),
				room_center + Vector2(0.0, marker_size),
				SPECIAL_MARKER_COLOR,
				2.0
			)
		"treasure":
			var marker_size := maxf(5.0, 6.0 * draw_scale)
			draw_rect(
				Rect2(
					room_center - Vector2(marker_size, marker_size * 0.65),
					Vector2(marker_size * 2.0, marker_size * 1.3)
				),
				TREASURE_MARKER_COLOR,
				false,
				2.0
			)
			draw_line(
				room_center - Vector2(0.0, marker_size * 0.65),
				room_center + Vector2(0.0, marker_size * 0.65),
				TREASURE_MARKER_COLOR,
				2.0
			)
		"final":
			var marker_size := maxf(4.0, 5.0 * draw_scale)
			draw_colored_polygon(PackedVector2Array([
				room_center + Vector2(0.0, -marker_size),
				room_center + Vector2(marker_size, 0.0),
				room_center + Vector2(0.0, marker_size),
				room_center + Vector2(-marker_size, 0.0),
			]), FINAL_MARKER_COLOR)


func set_exit_available(room_index: int, available: bool) -> void:
	exit_room_index = room_index
	exit_available = available
	queue_redraw()


func set_expanded(value: bool) -> void:
	if expanded == value:
		return

	expanded = value
	queue_redraw()


func is_expanded() -> bool:
	return expanded


func set_room_locked(room_index: int, locked: bool) -> void:
	if room_index < 0 or room_index >= room_positions.size():
		return

	locked_rooms[room_index] = locked
	queue_redraw()


func is_room_locked(room_index: int) -> bool:
	return bool(locked_rooms.get(room_index, false))


func _calculate_draw_scale() -> float:
	# The minimap acts as a window over the floor: the current room remains
	# centered while the visited graph may continue beyond the panel.
	if not expanded:
		return 1.0

	var graph_bounds := _calculate_graph_bounds()
	var available_size := Vector2(
		maxf(size.x - EXPANDED_MAP_PADDING.x * 2.0, 1.0),
		maxf(size.y - EXPANDED_MAP_PADDING.y * 2.0, 1.0)
	)
	var fit_scale := minf(
		available_size.x / maxf(graph_bounds.size.x, 1.0),
		available_size.y / maxf(graph_bounds.size.y, 1.0)
	)
	return clampf(
		fit_scale,
		EXPANDED_MINIMUM_SCALE,
		EXPANDED_MAXIMUM_SCALE
	)


func _calculate_map_origin(draw_scale: float) -> Vector2:
	if expanded:
		var graph_bounds := _calculate_graph_bounds()
		return (
			size * 0.5
			- graph_bounds.get_center() * draw_scale
		)

	return (
		size * 0.5
		- _room_unscaled_rect(current_room_index).get_center() * draw_scale
	)


func _calculate_graph_bounds() -> Rect2:
	var drawn_rooms := _get_drawn_room_indices()
	if drawn_rooms.is_empty():
		return Rect2(Vector2.ZERO, Vector2.ONE)

	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for room_index in drawn_rooms:
		var room_rect := _room_unscaled_rect(room_index)
		minimum = minimum.min(room_rect.position)
		maximum = maximum.max(room_rect.end)

	return Rect2(minimum, maximum - minimum)


func _room_unscaled_rect(room_index: int) -> Rect2:
	var display_size := _room_display_size(room_index)
	return Rect2(
		map_room_centers[room_index] - display_size * 0.5,
		display_size
	)


func _room_display_size(room_index: int) -> Vector2:
	if room_index >= 0 and room_index < map_room_sizes.size():
		return map_room_sizes[room_index]
	return ROOM_DISPLAY_SIZE


func _calculate_map_room_centers() -> void:
	map_room_sizes.clear()
	map_room_centers.clear()
	for room_index in range(room_positions.size()):
		var footprint_position := room_positions[room_index]
		var footprint_size := Vector2i.ONE
		if large_room_footprints.has(room_index):
			var footprint: Rect2i = large_room_footprints[room_index]
			footprint_position += footprint.position
			footprint_size = footprint.size

		var display_size := Vector2(footprint_size) * ROOM_DISPLAY_SIZE
		map_room_sizes.append(display_size)
		map_room_centers.append(
			(
				Vector2(footprint_position)
				+ Vector2(footprint_size) * 0.5
			) * ROOM_DISPLAY_SIZE
		)


func _door_local_position(
	room_index: int,
	direction: Vector2i
) -> Vector2:
	var display_size := _room_display_size(room_index)
	var tangent_ratio := 0.5
	if (
		room_index >= 0
		and room_index < room_door_ratios.size()
		and room_door_ratios[room_index].has(direction)
	):
		tangent_ratio = float(room_door_ratios[room_index][direction])

	if direction.x != 0:
		return Vector2(
			direction.x * display_size.x * 0.5,
			(tangent_ratio - 0.5) * display_size.y
		)
	return Vector2(
		(tangent_ratio - 0.5) * display_size.x,
		direction.y * display_size.y * 0.5
	)


func _get_drawn_room_indices() -> Array[int]:
	var room_indices: Array[int] = []
	for room_index in discovered_rooms:
		room_indices.append(room_index)
	room_indices.sort()
	return room_indices


func _draw_room_doors(
	room_index: int,
	room_center: Vector2,
	draw_scale: float
) -> void:
	for direction_value in room_door_cells[room_index]:
		var direction: Vector2i = direction_value
		var destination: int = room_connections[room_index][direction]
		var wall_edge_center := (
			room_center
			+ _door_local_position(room_index, direction) * draw_scale
		)
		var door_thickness := maxf(4.0, 5.0 * draw_scale)
		var door_length := maxf(8.0, 10.0 * draw_scale)
		var door_size := (
			Vector2(door_thickness, door_length)
			if direction.x != 0
			else Vector2(door_length, door_thickness)
		)
		var door_color := DOOR_COLOR
		var current_connection_locked := (
			room_index == current_room_index
			and bool(locked_rooms.get(room_index, false))
		)
		var destination_connection_locked := (
			destination == current_room_index
			and bool(locked_rooms.get(destination, false))
		)
		if current_connection_locked or destination_connection_locked:
			door_color = LOCKED_DOOR_COLOR

		draw_rect(
			Rect2(wall_edge_center - door_size * 0.5, door_size),
			door_color,
			true
		)


func _draw_room_shape(
	room_index: int,
	room_center: Vector2,
	draw_scale: float,
	room_color: Color,
	border_color: Color
) -> void:
	var room_rect := _room_display_rect(
		room_index,
		room_center,
		draw_scale
	)
	var outline_inset := maxf(1.0, 2.0 * draw_scale)
	var fill_inset := maxf(2.0, 4.0 * draw_scale)
	draw_rect(room_rect, ROOM_OUTLINE_COLOR, true)
	draw_rect(room_rect.grow(-outline_inset), border_color, true)
	draw_rect(room_rect.grow(-fill_inset), room_color, true)


func _room_display_rect(
	room_index: int,
	room_center: Vector2,
	draw_scale: float
) -> Rect2:
	var display_size := _room_display_size(room_index) * draw_scale
	return Rect2(
		room_center - display_size * 0.5,
		display_size
	)


func _draw_room_contents(
	room_index: int,
	room_center: Vector2,
	draw_scale: float
) -> void:
	var content_types := _get_room_content_types(room_index)
	var maximum_markers := 4 if expanded else 1
	if content_types.size() > maximum_markers:
		content_types.resize(maximum_markers)
	if content_types.is_empty():
		return

	var room_pixel_size := _room_display_size(room_index) * draw_scale
	var spacing := maxf(5.0, 6.0 * draw_scale)
	var row_width := spacing * float(content_types.size() - 1)
	var start_position := (
		room_center
		+ Vector2(-row_width * 0.5, room_pixel_size.y * 0.5)
		- Vector2(0.0, maxf(3.0, 3.8 * draw_scale))
	)

	for content_index in range(content_types.size()):
		_draw_content_marker(
			start_position + Vector2(spacing * content_index, 0.0),
			content_types[content_index],
			draw_scale
		)


func _get_room_content_types(room_index: int) -> Array[String]:
	var result: Array[String] = []
	for content_type in CONTENT_PRIORITY:
		var source := content_sources.get(content_type) as Node
		if not is_instance_valid(source):
			continue

		for content in source.get_children():
			if not _is_map_content_active(content, room_index, content_type):
				continue
			result.append(content_type)

	return result


func _is_map_content_active(
	content: Node,
	room_index: int,
	content_type: String
) -> bool:
	if (
		not is_instance_valid(content)
		or content.is_queued_for_deletion()
		or int(content.get_meta("room_index", -1)) != room_index
	):
		return false

	if content_type == "chest" and bool(content.get("is_open")):
		return false

	return not (content is CanvasItem) or content.visible


func _draw_content_marker(
	marker_position: Vector2,
	content_type: String,
	draw_scale: float
) -> void:
	var radius := maxf(2.5, 3.1 * draw_scale)
	draw_circle(marker_position, radius + 1.0, MARKER_BORDER_COLOR)

	match content_type:
		"health":
			draw_circle(marker_position, radius, HEALTH_CONTENT_COLOR)
			var cross_size := radius * 0.65
			draw_line(
				marker_position - Vector2(cross_size, 0.0),
				marker_position + Vector2(cross_size, 0.0),
				Color.WHITE,
				maxf(1.0, draw_scale)
			)
			draw_line(
				marker_position - Vector2(0.0, cross_size),
				marker_position + Vector2(0.0, cross_size),
				Color.WHITE,
				maxf(1.0, draw_scale)
			)
		"key":
			draw_circle(marker_position, radius, KEY_CONTENT_COLOR)
			draw_circle(
				marker_position - Vector2(radius * 0.3, 0.0),
				radius * 0.32,
				MARKER_BORDER_COLOR
			)
			draw_line(
				marker_position,
				marker_position + Vector2(radius * 0.85, 0.0),
				MARKER_BORDER_COLOR,
				maxf(1.0, draw_scale)
			)
		"relic":
			var diamond := PackedVector2Array([
				marker_position + Vector2(0.0, -radius),
				marker_position + Vector2(radius, 0.0),
				marker_position + Vector2(0.0, radius),
				marker_position + Vector2(-radius, 0.0),
			])
			draw_colored_polygon(diamond, RELIC_CONTENT_COLOR)
		"chest":
			draw_rect(
				Rect2(
					marker_position - Vector2(radius, radius * 0.65),
					Vector2(radius * 2.0, radius * 1.3)
				),
				CHEST_CONTENT_COLOR,
				true
			)
			draw_line(
				marker_position - Vector2(radius, 0.0),
				marker_position + Vector2(radius, 0.0),
				MARKER_BORDER_COLOR,
				maxf(1.0, draw_scale)
			)


func _draw_current_room_markers(
	room_center: Vector2,
	draw_scale: float
) -> void:
	for obstacle in obstacle_rects:
		if not _obstacle_belongs_to_room(obstacle, current_room_index):
			continue

		var obstacle_cell_position := (
			Vector2(obstacle.position) + Vector2(obstacle.size) * 0.5
		)
		var obstacle_position := _cell_position_to_map(
			current_room_index,
			obstacle_cell_position,
			room_center,
			draw_scale
		)
		_draw_marker(
			obstacle_position,
			maxf(2.0, 2.7 * draw_scale),
			OBSTACLE_MARKER_COLOR
		)

	if is_instance_valid(tracked_enemies):
		for enemy in tracked_enemies.get_children():
			if not _is_enemy_visible_on_map(enemy):
				continue

			var enemy_position := _world_position_to_map(
				current_room_index,
				enemy.global_position,
				room_center,
				draw_scale
			)
			_draw_marker(
				enemy_position,
				maxf(2.6, 3.5 * draw_scale),
				ENEMY_MARKER_COLOR
			)

	if is_instance_valid(tracked_player):
		var player_position := _world_position_to_map(
			current_room_index,
			tracked_player.global_position,
			room_center,
			draw_scale
		)
		_draw_marker(
			player_position,
			maxf(3.0, 4.0 * draw_scale),
			PLAYER_MARKER_COLOR
		)


func _draw_marker(position_value: Vector2, radius: float, color: Color) -> void:
	draw_circle(position_value, radius + 1.0, MARKER_BORDER_COLOR)
	draw_circle(position_value, radius, color)


func _world_position_to_map(
	room_index: int,
	world_position: Vector2,
	room_center: Vector2,
	draw_scale: float
) -> Vector2:
	return _cell_position_to_map(
		room_index,
		world_position / world_cell_size,
		room_center,
		draw_scale
	)


func _cell_position_to_map(
	room_index: int,
	cell_position: Vector2,
	room_center: Vector2,
	draw_scale: float
) -> Vector2:
	var bounds := room_bounds[room_index]
	var room_size := _room_display_size(room_index) * draw_scale
	var local_position := cell_position - Vector2(bounds.position)
	var normalized_position := local_position / Vector2(bounds.size)
	return room_center - room_size * 0.5 + normalized_position * room_size


func _obstacle_belongs_to_room(obstacle: Rect2i, room_index: int) -> bool:
	return room_cells[room_index].has(obstacle.position)


func _is_enemy_visible_on_map(enemy: Node) -> bool:
	return (
		is_instance_valid(enemy)
		and not enemy.is_queued_for_deletion()
		and enemy is Node2D
		and enemy.get_meta("room_index", -1) == current_room_index
	)


func get_current_room_draw_position() -> Vector2:
	if current_room_index < 0:
		return Vector2.ZERO

	var draw_scale := _calculate_draw_scale()
	var map_origin := _calculate_map_origin(draw_scale)
	return _room_draw_position(current_room_index, map_origin, draw_scale)


func get_room_layout_rect(room_index: int) -> Rect2:
	if room_index < 0 or room_index >= room_positions.size():
		return Rect2()
	return _room_unscaled_rect(room_index)


func get_room_door_layout_position(
	room_index: int,
	direction: Vector2i
) -> Vector2:
	if room_index < 0 or room_index >= room_positions.size():
		return Vector2.ZERO
	return (
		map_room_centers[room_index]
		+ _door_local_position(room_index, direction)
	)


func get_room_display_rect(room_index: int) -> Rect2:
	if not discovered_rooms.has(room_index):
		return Rect2()

	var draw_scale := _calculate_draw_scale()
	var map_origin := _calculate_map_origin(draw_scale)
	var room_center := _room_draw_position(
		room_index,
		map_origin,
		draw_scale
	)
	return _room_display_rect(room_index, room_center, draw_scale)


func get_drawn_room_count() -> int:
	return _get_drawn_room_indices().size()


func get_visited_room_count() -> int:
	return visited_rooms.size()


func get_discovered_room_count() -> int:
	return discovered_rooms.size()


func get_total_room_count() -> int:
	return room_positions.size()


func get_visible_content_marker_count(room_index: int) -> int:
	if not visited_rooms.has(room_index):
		return 0

	return mini(
		_get_room_content_types(room_index).size(),
		4 if expanded else 1
	)


func get_visible_door_count(room_index: int) -> int:
	if not visited_rooms.has(room_index):
		return 0

	return room_connections[room_index].size()


func get_room_shape_cell_count(room_index: int) -> int:
	if room_index < 0 or room_index >= room_cells.size():
		return 0

	return room_cells[room_index].size()


func get_room_footprint_size(room_index: int) -> Vector2i:
	if room_index < 0 or room_index >= room_positions.size():
		return Vector2i.ZERO
	if large_room_footprints.has(room_index):
		var footprint: Rect2i = large_room_footprints[room_index]
		return footprint.size
	return Vector2i.ONE


func get_room_type(room_index: int) -> String:
	if room_index < 0 or room_index >= room_types.size():
		return ""

	return room_types[room_index]


func is_exit_marker_visible() -> bool:
	return (
		exit_available
		and exit_room_index >= 0
		and visited_rooms.has(exit_room_index)
	)


func get_visible_enemy_marker_count() -> int:
	if not is_instance_valid(tracked_enemies):
		return 0

	var count := 0
	for enemy in tracked_enemies.get_children():
		if _is_enemy_visible_on_map(enemy):
			count += 1
	return count


func get_current_room_obstacle_marker_count() -> int:
	var count := 0
	for obstacle in obstacle_rects:
		if _obstacle_belongs_to_room(obstacle, current_room_index):
			count += 1
	return count


func _room_draw_position(
	room_index: int,
	map_origin: Vector2,
	draw_scale: float
) -> Vector2:
	return (
		map_origin
		+ _room_unscaled_rect(room_index).get_center() * draw_scale
	)
