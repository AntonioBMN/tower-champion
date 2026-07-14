class_name FloorMinimap
extends Control

const ROOM_STEP := Vector2(52.0, 40.0)
const ROOM_CELL_SIZE := 1.8
const MARKER_REFRESH_INTERVAL := 0.05
const CONNECTION_COLOR := Color(0.42, 0.46, 0.56, 0.9)
const VISITED_ROOM_COLOR := Color(0.3, 0.34, 0.43, 1.0)
const CURRENT_ROOM_COLOR := Color(0.96, 0.68, 0.18, 1.0)
const ROOM_BORDER_COLOR := Color(0.76, 0.79, 0.86, 1.0)
const DOOR_COLOR := Color(0.86, 0.88, 0.94, 1.0)
const PLAYER_MARKER_COLOR := Color(0.2, 0.95, 0.72, 1.0)
const ENEMY_MARKER_COLOR := Color(0.95, 0.18, 0.16, 1.0)
const OBSTACLE_MARKER_COLOR := Color(0.64, 0.66, 0.7, 1.0)
const MARKER_BORDER_COLOR := Color(0.08, 0.09, 0.12, 0.95)
const FINAL_ROOM_COLOR := Color(0.52, 0.16, 0.18, 1.0)
const SPECIAL_ROOM_COLOR := Color(0.27, 0.2, 0.5, 1.0)
const START_MARKER_COLOR := Color(0.3, 0.72, 1.0, 1.0)
const FINAL_MARKER_COLOR := Color(1.0, 0.28, 0.24, 1.0)
const SPECIAL_MARKER_COLOR := Color(0.76, 0.5, 1.0, 1.0)
const EXIT_MARKER_COLOR := Color(0.28, 1.0, 0.7, 1.0)

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
var current_room_index: int = -1
var exit_room_index: int = -1
var exit_available: bool = false
var marker_refresh_elapsed: float = 0.0


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
	world_cell_size_value: float
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
	visited_rooms.clear()
	current_room_index = -1
	exit_room_index = -1
	exit_available = false
	queue_redraw()


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
	current_room_index = room_index
	queue_redraw()


func _draw() -> void:
	if visited_rooms.is_empty() or current_room_index < 0:
		return

	var draw_scale := _calculate_draw_scale()
	var map_origin := _calculate_map_origin(draw_scale)

	for room_index in visited_rooms:
		for destination in room_connections[room_index].values():
			if not visited_rooms.has(destination) or room_index >= destination:
				continue

			draw_line(
				_room_draw_position(room_index, map_origin, draw_scale),
				_room_draw_position(destination, map_origin, draw_scale),
				CONNECTION_COLOR,
				maxf(2.0, 4.0 * draw_scale),
				true
			)

	for room_index in visited_rooms:
		var center := _room_draw_position(room_index, map_origin, draw_scale)
		var room_color := _room_color(room_index)

		_draw_room_shape(room_index, center, draw_scale, room_color)
		_draw_room_doors(room_index, center, draw_scale)
		_draw_room_role_marker(room_index, center, draw_scale)

	var current_room_center := _room_draw_position(
		current_room_index,
		map_origin,
		draw_scale
	)
	_draw_current_room_markers(current_room_center, draw_scale)


func _room_color(room_index: int) -> Color:
	if room_index == current_room_index:
		return CURRENT_ROOM_COLOR

	match room_types[room_index]:
		"final":
			return FINAL_ROOM_COLOR
		"special":
			return SPECIAL_ROOM_COLOR
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


func _calculate_draw_scale() -> float:
	# O minimapa funciona como uma janela sobre o andar: a sala atual fica
	# centralizada e o grafo visitado pode continuar para fora do painel.
	return 1.0


func _calculate_map_origin(draw_scale: float) -> Vector2:
	return (
		size * 0.5
		- Vector2(room_positions[current_room_index]) * ROOM_STEP * draw_scale
	)


func _draw_room_doors(
	room_index: int,
	room_center: Vector2,
	draw_scale: float
) -> void:
	var cell_size := ROOM_CELL_SIZE * draw_scale

	for direction_value in room_door_cells[room_index]:
		var direction: Vector2i = direction_value
		var door_cell: Vector2i = room_door_cells[room_index][direction]
		var door_cell_rect := _room_cell_rect(
			room_index, door_cell, room_center, draw_scale
		)
		var door_thickness := maxf(2.5, 3.2 * draw_scale)
		var desired_door_length := maxf(6.0, 9.0 * draw_scale)
		var wall_span := _door_wall_span_cells(
			room_index, door_cell, direction
		)
		var available_door_length := maxf(
			cell_size,
			wall_span * cell_size - 0.4
		)
		var door_length := minf(
			desired_door_length,
			available_door_length
		)
		var door_size := (
			Vector2(door_thickness, door_length)
			if direction.x != 0
			else Vector2(door_length, door_thickness)
		)
		var wall_edge_center := (
			door_cell_rect.get_center()
			+ Vector2(direction) * cell_size * 0.5
		)
		# Mantem toda a espessura da porta dentro do contorno da sala.
		var door_center := (
			wall_edge_center
			- Vector2(direction) * door_thickness * 0.5
		)

		draw_rect(
			Rect2(door_center - door_size * 0.5, door_size),
			DOOR_COLOR,
			true
		)


func _door_wall_span_cells(
	room_index: int,
	door_cell: Vector2i,
	direction: Vector2i
) -> int:
	var cells: Dictionary = room_cells[room_index]
	var tangent := Vector2i(-direction.y, direction.x)
	var span := 1

	for tangent_sign_value in [-1, 1]:
		var tangent_sign: int = tangent_sign_value
		var candidate: Vector2i = door_cell + tangent * tangent_sign
		while (
			cells.has(candidate)
			and not cells.has(candidate + direction)
		):
			span += 1
			candidate += tangent * tangent_sign

	return span


func _draw_room_shape(
	room_index: int,
	room_center: Vector2,
	draw_scale: float,
	room_color: Color
) -> void:
	var cells: Dictionary = room_cells[room_index]

	for cell_value in cells:
		var cell: Vector2i = cell_value
		var cell_rect := _room_cell_rect(
			room_index,
			cell,
			room_center,
			draw_scale
		)
		# A pequena sobreposicao evita frestas entre celulas adjacentes.
		cell_rect = cell_rect.grow(0.08)
		draw_rect(cell_rect, room_color, true)

	for cell_value in cells:
		var cell: Vector2i = cell_value
		var cell_rect := _room_cell_rect(
			room_index,
			cell,
			room_center,
			draw_scale
		)
		_draw_cell_border(cell, cell_rect, cells, draw_scale)


func _draw_cell_border(
	cell: Vector2i,
	cell_rect: Rect2,
	cells: Dictionary,
	draw_scale: float
) -> void:
	var border_width := maxf(1.0, 1.4 * draw_scale)
	var top_left := cell_rect.position
	var top_right := cell_rect.position + Vector2(cell_rect.size.x, 0.0)
	var bottom_left := cell_rect.position + Vector2(0.0, cell_rect.size.y)
	var bottom_right := cell_rect.end

	if not cells.has(cell + Vector2i.UP):
		draw_line(top_left, top_right, ROOM_BORDER_COLOR, border_width)
	if not cells.has(cell + Vector2i.DOWN):
		draw_line(bottom_left, bottom_right, ROOM_BORDER_COLOR, border_width)
	if not cells.has(cell + Vector2i.LEFT):
		draw_line(top_left, bottom_left, ROOM_BORDER_COLOR, border_width)
	if not cells.has(cell + Vector2i.RIGHT):
		draw_line(top_right, bottom_right, ROOM_BORDER_COLOR, border_width)


func _room_cell_rect(
	room_index: int,
	cell: Vector2i,
	room_center: Vector2,
	draw_scale: float
) -> Rect2:
	var bounds := room_bounds[room_index]
	var cell_size := ROOM_CELL_SIZE * draw_scale
	var room_size := Vector2(bounds.size) * cell_size
	var local_cell := cell - bounds.position
	return Rect2(
		room_center - room_size * 0.5 + Vector2(local_cell) * cell_size,
		Vector2.ONE * cell_size
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
	var cell_size := ROOM_CELL_SIZE * draw_scale
	var room_size := Vector2(bounds.size) * cell_size
	var local_position := cell_position - Vector2(bounds.position)
	return room_center - room_size * 0.5 + local_position * cell_size


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


func get_visible_door_count(room_index: int) -> int:
	if not visited_rooms.has(room_index):
		return 0

	return room_connections[room_index].size()


func get_room_shape_cell_count(room_index: int) -> int:
	if room_index < 0 or room_index >= room_cells.size():
		return 0

	return room_cells[room_index].size()


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
		+ Vector2(room_positions[room_index]) * ROOM_STEP * draw_scale
	)
