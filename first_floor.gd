extends Node2D

const CELL_SIZE := 64
const ATLAS_TILE_SIZE := Vector2i(32, 32)
const ROOM_GRID_SPACING := Vector2i(34, 24)
const MAP_ORIGIN := Vector2i(120, 100)
const FLOOR_TEXTURE: Texture2D = preload(
	"res://sprites/map/dungeon/dungeon_tiles_32px.png"
)
const ENEMY_SCENE: PackedScene = preload("res://enemy.tscn")
const RANGED_ENEMY_SCENE: PackedScene = preload("res://ranged_enemy.tscn")
const HEALTH_PICKUP_SCENE: PackedScene = preload("res://health_pickup.tscn")
const FLOOR_EXIT_SCENE: PackedScene = preload("res://floor_exit.tscn")
const DOOR_LOCKED_COLOR := Color(0.75, 0.16, 0.12, 0.95)
const DOOR_OPEN_COLOR := Color(0.95, 0.67, 0.2, 0.95)
const ROOM_TYPE_START := "start"
const ROOM_TYPE_NORMAL := "normal"
const ROOM_TYPE_SPECIAL := "special"
const ROOM_TYPE_FINAL := "final"

@export_group("Generation")
@export var randomize_layout: bool = true
@export var fixed_seed: int = 12345
@export_range(5, 8, 1) var minimum_rooms: int = 5
@export_range(5, 8, 1) var maximum_rooms: int = 8

@export_group("Room Rewards")
@export_range(0.0, 1.0, 0.05) var health_drop_chance: float = 0.35
@export_range(1, 10, 1) var health_pickup_amount: int = 1

var rng := RandomNumberGenerator.new()
var generation_seed: int
var generated_room_count: int
var floor_cells: Dictionary = {}
var obstacle_cells: Dictionary = {}
var room_grid_positions: Array[Vector2i] = []
var room_bounds: Array[Rect2i] = []
var room_cells: Array = []
var room_connections: Array = []
var room_door_cells: Array = []
var room_types: Array[String] = []
var room_distances: Array[int] = []
var open_edges: Dictionary = {}
var obstacle_rects: Array[Rect2i] = []
var enemy_spawn_cells: Array = []
var room_enemies_remaining: Array[int] = []
var spawned_rooms: Dictionary = {}
var rewarded_rooms: Dictionary = {}
var special_rewarded_rooms: Dictionary = {}
var door_entries: Array[Dictionary] = []
var current_room_index: int = 0
var final_room_index: int = -1
var special_room_index: int = -1
var remaining_enemies: int = 0
var floor_is_cleared: bool = false
var exit_is_available: bool = false
var run_is_complete: bool = false
var floor_exit: Area2D
var floor_exit_cell: Vector2i
var is_transitioning: bool = false

@onready var floor_tiles: TileMapLayer = $GeneratedMap/FloorTiles
@onready var wall_tiles: TileMapLayer = $GeneratedMap/WallTiles
@onready var walls: StaticBody2D = $GeneratedMap/Walls
@onready var obstacles: StaticBody2D = $GeneratedMap/Obstacles
@onready var doors: Node2D = $GeneratedMap/Doors
@onready var enemies: Node2D = $Enemies
@onready var pickups: Node2D = $Pickups
@onready var exits: Node2D = $Exits
@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Player/Camera2D
@onready var hud = $UI
@onready var enemy_counter_label: Label = $UI/EnemyCounterLabel
@onready var room_label: Label = $UI/RoomLabel
@onready var seed_label: Label = $UI/SeedLabel
@onready var floor_cleared_label: Label = $UI/FloorClearedLabel
@onready var transition_fade: ColorRect = $UI/TransitionFade
@onready var victory_overlay: ColorRect = $UI/VictoryOverlay
@onready var victory_details: Label = $UI/VictoryOverlay/VictoryDetails
@onready var minimap = $UI/MinimapPanel/Minimap


func _ready() -> void:
	hud.bind_health(player.health_component)
	_configure_seed()
	_configure_tilemaps()
	_generate_floor()
	minimap.configure(
		room_grid_positions,
		room_connections,
		room_bounds,
		room_cells,
		room_door_cells,
		room_types,
		obstacle_rects,
		player,
		enemies,
		CELL_SIZE
	)
	minimap.visit_room(0)
	_validate_floor()
	_paint_tiles()
	_build_wall_and_obstacle_collisions()
	_build_doors()
	_place_player_at_start()
	_configure_camera_for_room(0)
	_update_enemy_counter()

	transition_fade.hide()
	victory_overlay.hide()
	floor_cleared_label.hide()
	seed_label.text = "Andar 1  •  Seed: " + str(generation_seed)
	_spawn_room_enemies(0)
	_update_room_ui()


func _unhandled_input(event: InputEvent) -> void:
	if (
		event.is_action_pressed("restart_scene")
		and (not is_transitioning or run_is_complete)
	):
		get_viewport().set_input_as_handled()
		get_tree().reload_current_scene()


func _configure_seed() -> void:
	if randomize_layout:
		generation_seed = (
			int(Time.get_unix_time_from_system())
			^ Time.get_ticks_usec()
		)
	else:
		generation_seed = fixed_seed

	rng.seed = generation_seed


func _configure_tilemaps() -> void:
	var tile_set := TileSet.new()
	tile_set.tile_size = ATLAS_TILE_SIZE

	var atlas := TileSetAtlasSource.new()
	atlas.texture = FLOOR_TEXTURE
	atlas.texture_region_size = ATLAS_TILE_SIZE

	for y in range(4):
		for x in range(4):
			atlas.create_tile(Vector2i(x, y))

	tile_set.add_source(atlas, 0)
	floor_tiles.tile_set = tile_set
	wall_tiles.tile_set = tile_set


func _generate_floor() -> void:
	floor_cells.clear()
	obstacle_cells.clear()
	room_grid_positions.clear()
	room_bounds.clear()
	room_cells.clear()
	room_connections.clear()
	room_door_cells.clear()
	room_types.clear()
	room_distances.clear()
	open_edges.clear()
	obstacle_rects.clear()
	enemy_spawn_cells.clear()
	room_enemies_remaining.clear()
	spawned_rooms.clear()
	rewarded_rooms.clear()
	special_rewarded_rooms.clear()
	final_room_index = -1
	special_room_index = -1
	floor_is_cleared = false
	exit_is_available = false
	run_is_complete = false

	var minimum := mini(minimum_rooms, maximum_rooms)
	var maximum := maxi(minimum_rooms, maximum_rooms)
	generated_room_count = rng.randi_range(minimum, maximum)

	_generate_room_graph()
	_assign_room_roles()
	_generate_room_shapes()
	_configure_room_doors()
	_generate_obstacles()
	_prepare_enemy_spawns()


func _generate_room_graph() -> void:
	var occupied: Dictionary = {Vector2i.ZERO: 0}
	room_grid_positions.append(Vector2i.ZERO)
	room_connections.append({})

	while room_grid_positions.size() < generated_room_count:
		var expandable_rooms: Array[int] = []

		for room_index in range(room_grid_positions.size()):
			if not _free_directions(room_grid_positions[room_index], occupied).is_empty():
				expandable_rooms.append(room_index)

		var parent_index := expandable_rooms[
			rng.randi_range(0, expandable_rooms.size() - 1)
		]
		var free_directions := _free_directions(
			room_grid_positions[parent_index],
			occupied
		)
		var direction: Vector2i = free_directions[
			rng.randi_range(0, free_directions.size() - 1)
		]
		var new_position := room_grid_positions[parent_index] + direction
		var new_index := room_grid_positions.size()

		room_grid_positions.append(new_position)
		room_connections.append({})
		occupied[new_position] = new_index
		room_connections[parent_index][direction] = new_index
		room_connections[new_index][-direction] = parent_index

	# Occasionally add a loop while preserving full connectivity.
	for room_index in range(room_grid_positions.size()):
		for direction in [Vector2i.RIGHT, Vector2i.DOWN]:
			var neighbor_position: Vector2i = (
				room_grid_positions[room_index] + direction
			)

			if (
				occupied.has(neighbor_position)
				and not room_connections[room_index].has(direction)
				and rng.randf() < 0.28
			):
				var neighbor_index: int = occupied[neighbor_position]
				room_connections[room_index][direction] = neighbor_index
				room_connections[neighbor_index][-direction] = room_index


func _assign_room_roles() -> void:
	room_types.resize(generated_room_count)
	room_types.fill(ROOM_TYPE_NORMAL)
	room_types[0] = ROOM_TYPE_START

	room_distances.resize(generated_room_count)
	room_distances.fill(-1)
	room_distances[0] = 0
	var pending: Array[int] = [0]
	var pending_index := 0

	while pending_index < pending.size():
		var room_index := pending[pending_index]
		pending_index += 1

		for destination in room_connections[room_index].values():
			if room_distances[destination] >= 0:
				continue

			room_distances[destination] = room_distances[room_index] + 1
			pending.append(destination)

	final_room_index = 1
	for room_index in range(2, generated_room_count):
		if room_distances[room_index] > room_distances[final_room_index]:
			final_room_index = room_index
		elif (
			room_distances[room_index] == room_distances[final_room_index]
			and room_connections[room_index].size()
			< room_connections[final_room_index].size()
		):
			final_room_index = room_index

	room_types[final_room_index] = ROOM_TYPE_FINAL

	var special_candidates: Array[int] = []
	for room_index in range(1, generated_room_count):
		if room_index == final_room_index:
			continue

		if room_connections[room_index].size() == 1:
			special_candidates.append(room_index)

	if special_candidates.is_empty():
		for room_index in range(1, generated_room_count):
			if room_index != final_room_index:
				special_candidates.append(room_index)

	special_room_index = special_candidates[
		rng.randi_range(0, special_candidates.size() - 1)
	]
	room_types[special_room_index] = ROOM_TYPE_SPECIAL


func _free_directions(position: Vector2i, occupied: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []

	for direction in _cardinal_directions():
		if not occupied.has(position + direction):
			result.append(direction)

	return result


func _cardinal_directions() -> Array[Vector2i]:
	return [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]


func _generate_room_shapes() -> void:
	room_cells.resize(generated_room_count)

	for room_index in range(generated_room_count):
		room_cells[room_index] = {}
		var size := _room_size(room_index)
		var center := (
			MAP_ORIGIN
			+ room_grid_positions[room_index] * ROOM_GRID_SPACING
		)
		var rect := Rect2i(center - size / 2, size)
		room_bounds.append(rect)

		match room_index % 5:
			2:
				_fill_l_room(room_index, rect)
			3:
				_fill_cross_room(room_index, rect)
			_:
				_fill_room_rect(room_index, rect)


func _room_size(room_index: int) -> Vector2i:
	match room_index % 5:
		1:
			return Vector2i(rng.randi_range(21, 24), rng.randi_range(11, 12))
		2:
			return Vector2i(rng.randi_range(20, 23), rng.randi_range(13, 15))
		3:
			return Vector2i(rng.randi_range(20, 22), rng.randi_range(13, 15))
		4:
			return Vector2i(rng.randi_range(18, 20), rng.randi_range(14, 16))
		_:
			return Vector2i(rng.randi_range(18, 20), rng.randi_range(11, 13))


func _fill_room_rect(room_index: int, rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			_add_room_cell(room_index, Vector2i(x, y))


func _fill_l_room(room_index: int, rect: Rect2i) -> void:
	var upper_height := maxi(7, int(rect.size.y * 0.58))
	var lower_width := maxi(11, int(rect.size.x * 0.62))

	_fill_room_rect(
		room_index,
		Rect2i(rect.position, Vector2i(rect.size.x, upper_height))
	)
	_fill_room_rect(
		room_index,
		Rect2i(
			rect.position + Vector2i(0, upper_height),
			Vector2i(lower_width, rect.size.y - upper_height)
		)
	)


func _fill_cross_room(room_index: int, rect: Rect2i) -> void:
	var vertical_width := maxi(12, int(rect.size.x * 0.62))
	var horizontal_height := maxi(8, int(rect.size.y * 0.62))
	var vertical_x := rect.position.x + int((rect.size.x - vertical_width) * 0.5)
	var horizontal_y := rect.position.y + int((rect.size.y - horizontal_height) * 0.5)

	_fill_room_rect(
		room_index,
		Rect2i(
			Vector2i(vertical_x, rect.position.y),
			Vector2i(vertical_width, rect.size.y)
		)
	)
	_fill_room_rect(
		room_index,
		Rect2i(
			Vector2i(rect.position.x, horizontal_y),
			Vector2i(rect.size.x, horizontal_height)
		)
	)


func _add_room_cell(room_index: int, cell: Vector2i) -> void:
	room_cells[room_index][cell] = true
	floor_cells[cell] = true


func _configure_room_doors() -> void:
	room_door_cells.resize(generated_room_count)

	for room_index in range(generated_room_count):
		room_door_cells[room_index] = {}

		for direction in room_connections[room_index]:
			var door_cell := _find_door_cell(room_index, direction)
			room_door_cells[room_index][direction] = door_cell

			if not open_edges.has(door_cell):
				open_edges[door_cell] = {}

			open_edges[door_cell][direction] = true


func _find_door_cell(room_index: int, direction: Vector2i) -> Vector2i:
	var cells: Dictionary = room_cells[room_index]
	var center := _room_center_cell(room_index)
	var extreme := 1000000 if direction in [Vector2i.UP, Vector2i.LEFT] else -1000000

	for key in cells:
		var cell: Vector2i = key
		var coordinate := cell.y if direction.y != 0 else cell.x

		if direction in [Vector2i.UP, Vector2i.LEFT]:
			extreme = mini(extreme, coordinate)
		else:
			extreme = maxi(extreme, coordinate)

	var best_cell := center
	var best_distance := 1000000

	for key in cells:
		var cell: Vector2i = key
		var coordinate := cell.y if direction.y != 0 else cell.x

		if coordinate != extreme:
			continue

		var distance := (
			absi(cell.x - center.x)
			if direction.y != 0
			else absi(cell.y - center.y)
		)

		if distance < best_distance:
			best_distance = distance
			best_cell = cell

	return best_cell


func _is_open_edge(cell: Vector2i, direction: Vector2i) -> bool:
	return open_edges.has(cell) and open_edges[cell].has(direction)


func _generate_obstacles() -> void:
	for room_index in range(generated_room_count):
		var center := _room_center_cell(room_index)
		var desired_count := 1 if room_index == 0 else 1 + (room_index % 2)
		var candidates := [
			Rect2i(center + Vector2i(-5, -2), Vector2i(2, 2)),
			Rect2i(center + Vector2i(3, 2), Vector2i(3, 1)),
			Rect2i(center + Vector2i(-1, 4), Vector2i(2, 2)),
			Rect2i(center + Vector2i(4, -4), Vector2i(1, 3)),
		]
		var added := 0

		for candidate in candidates:
			if added >= desired_count:
				break

			if _can_place_obstacle(room_index, candidate):
				_add_obstacle(candidate)
				added += 1


func _can_place_obstacle(room_index: int, rect: Rect2i) -> bool:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var cell := Vector2i(x, y)

			if not room_cells[room_index].has(cell) or obstacle_cells.has(cell):
				return false

			for door_cell in room_door_cells[room_index].values():
				var offset: Vector2i = cell - door_cell

				if absi(offset.x) + absi(offset.y) < 4:
					return false

	return true


func _add_obstacle(rect: Rect2i) -> void:
	obstacle_rects.append(rect)

	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			obstacle_cells[Vector2i(x, y)] = true


func _prepare_enemy_spawns() -> void:
	enemy_spawn_cells.resize(generated_room_count)
	room_enemies_remaining.resize(generated_room_count)
	remaining_enemies = 0

	var offsets := [
		Vector2i(5, 0),
		Vector2i(-5, 0),
		Vector2i(0, 4),
		Vector2i(0, -4),
		Vector2i(5, 3),
		Vector2i(-5, -3),
	]

	for room_index in range(generated_room_count):
		var spawn_count := 0
		match room_types[room_index]:
			ROOM_TYPE_START, ROOM_TYPE_SPECIAL:
				spawn_count = 0
			ROOM_TYPE_FINAL:
				spawn_count = 3
			_:
				spawn_count = rng.randi_range(1, 2)
		var center := _room_center_cell(room_index)
		var reserved: Dictionary = {}
		var spawns: Array[Vector2i] = []

		for spawn_index in range(spawn_count):
			var preferred: Vector2i = center + offsets[spawn_index % offsets.size()]
			var spawn := _find_safe_cell(room_index, preferred, reserved)
			spawns.append(spawn)
			reserved[spawn] = true

		enemy_spawn_cells[room_index] = spawns
		room_enemies_remaining[room_index] = spawns.size()
		remaining_enemies += spawns.size()


func _find_safe_cell(
	room_index: int,
	preferred: Vector2i,
	reserved: Dictionary = {}
) -> Vector2i:
	if _is_spawn_cell_safe(room_index, preferred, reserved):
		return preferred

	var rect := room_bounds[room_index]

	for y in range(rect.position.y + 2, rect.position.y + rect.size.y - 2):
		for x in range(rect.position.x + 2, rect.position.x + rect.size.x - 2):
			var candidate := Vector2i(x, y)

			if _is_spawn_cell_safe(room_index, candidate, reserved):
				return candidate

	return _room_center_cell(room_index)


func _is_spawn_cell_safe(
	room_index: int,
	cell: Vector2i,
	reserved: Dictionary
) -> bool:
	if (
		not room_cells[room_index].has(cell)
		or obstacle_cells.has(cell)
		or reserved.has(cell)
	):
		return false

	for door_cell in room_door_cells[room_index].values():
		var offset: Vector2i = cell - door_cell

		if absi(offset.x) + absi(offset.y) < 3:
			return false

	return true


func _room_center_cell(room_index: int) -> Vector2i:
	var rect := room_bounds[room_index]
	return rect.position + Vector2i(
		int(rect.size.x * 0.5),
		int(rect.size.y * 0.5)
	)


func _paint_tiles() -> void:
	floor_tiles.clear()
	wall_tiles.clear()

	var floor_variants := [
		Vector2i(0, 3),
		Vector2i(1, 3),
		Vector2i(2, 3),
		Vector2i(3, 3),
	]

	for key in floor_cells:
		var cell: Vector2i = key
		var variant: Vector2i = floor_variants[
			rng.randi_range(0, floor_variants.size() - 1)
		]
		floor_tiles.set_cell(cell, 0, variant)

		for direction in _cardinal_directions():
			var outside_cell := cell + direction

			if (
				not floor_cells.has(outside_cell)
				and not _is_open_edge(cell, direction)
			):
				wall_tiles.set_cell(outside_cell, 0, Vector2i(0, 0))

	for key in obstacle_cells:
		var obstacle_cell: Vector2i = key
		wall_tiles.set_cell(obstacle_cell, 0, Vector2i(2, 0))


func _build_wall_and_obstacle_collisions() -> void:
	for key in floor_cells:
		var cell: Vector2i = key

		for direction in _cardinal_directions():
			if (
				floor_cells.has(cell + direction)
				or _is_open_edge(cell, direction)
			):
				continue

			var size := (
				Vector2(CELL_SIZE, 12)
				if direction.y != 0
				else Vector2(12, CELL_SIZE)
			)
			_add_collision_shape(walls, _boundary_center(cell, direction), size)

	for rect in obstacle_rects:
		var size := Vector2(rect.size * CELL_SIZE)
		var center := Vector2(rect.position * CELL_SIZE) + size * 0.5
		_add_collision_shape(obstacles, center, size)


func _boundary_center(cell: Vector2i, direction: Vector2i) -> Vector2:
	return (
		Vector2(cell * CELL_SIZE)
		+ Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5)
		+ Vector2(direction) * CELL_SIZE * 0.5
	)


func _add_collision_shape(
	parent: StaticBody2D,
	position_value: Vector2,
	size: Vector2
) -> CollisionShape2D:
	var shape := RectangleShape2D.new()
	shape.size = size

	var collision := CollisionShape2D.new()
	collision.position = position_value
	collision.shape = shape
	parent.add_child(collision)
	return collision


func _build_doors() -> void:
	door_entries.clear()

	for room_index in range(generated_room_count):
		for direction in room_connections[room_index]:
			var destination: int = room_connections[room_index][direction]
			var door_cell: Vector2i = room_door_cells[room_index][direction]
			var center := _boundary_center(door_cell, direction)
			var vertical_door: bool = direction.x != 0
			var blocker_size := (
				Vector2(12, CELL_SIZE - 8)
				if vertical_door
				else Vector2(CELL_SIZE - 8, 12)
			)
			var trigger_size := (
				Vector2(52, CELL_SIZE - 8)
				if vertical_door
				else Vector2(CELL_SIZE - 8, 52)
			)

			var blocker := StaticBody2D.new()
			blocker.collision_layer = 8
			blocker.collision_mask = 7
			blocker.position = center
			doors.add_child(blocker)
			var blocker_collision := _add_collision_shape(
				blocker,
				Vector2.ZERO,
				blocker_size
			)

			var trigger := Area2D.new()
			trigger.collision_layer = 0
			trigger.collision_mask = 1
			trigger.monitorable = false
			trigger.position = center
			doors.add_child(trigger)
			_add_area_collision(trigger, trigger_size)
			trigger.body_entered.connect(
				_on_door_body_entered.bind(room_index, destination, direction)
			)

			var visual := Polygon2D.new()
			visual.position = center
			visual.polygon = _rectangle_polygon(blocker_size + Vector2(8, 8))
			visual.color = DOOR_LOCKED_COLOR
			doors.add_child(visual)

			door_entries.append({
				"room": room_index,
				"collision": blocker_collision,
				"visual": visual,
			})

	for room_index in range(generated_room_count):
		_refresh_room_doors(room_index)


func _add_area_collision(area: Area2D, size: Vector2) -> void:
	var shape := RectangleShape2D.new()
	shape.size = size

	var collision := CollisionShape2D.new()
	collision.shape = shape
	area.add_child(collision)


func _rectangle_polygon(size: Vector2) -> PackedVector2Array:
	var half := size * 0.5
	return PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])


func _refresh_room_doors(room_index: int) -> void:
	var locked := room_enemies_remaining[room_index] > 0

	for entry in door_entries:
		if entry["room"] != room_index:
			continue

		var collision := entry["collision"] as CollisionShape2D
		var visual := entry["visual"] as Polygon2D
		collision.set_deferred("disabled", not locked)
		visual.color = DOOR_LOCKED_COLOR if locked else DOOR_OPEN_COLOR


func _place_player_at_start() -> void:
	var start_cell := _find_safe_cell(0, _room_center_cell(0))
	player.global_position = _actor_position_for_cell(start_cell)


func _actor_position_for_cell(cell: Vector2i) -> Vector2:
	return (
		Vector2(cell * CELL_SIZE)
		+ Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5 - 50.0)
	)


func _configure_camera_for_room(room_index: int) -> void:
	var rect := room_bounds[room_index]
	camera.limit_left = (rect.position.x - 1) * CELL_SIZE
	camera.limit_top = (rect.position.y - 1) * CELL_SIZE
	camera.limit_right = (rect.position.x + rect.size.x + 1) * CELL_SIZE
	camera.limit_bottom = (rect.position.y + rect.size.y + 1) * CELL_SIZE
	camera.reset_smoothing()


func _on_door_body_entered(
	body: Node2D,
	from_room: int,
	destination_room: int,
	direction: Vector2i
) -> void:
	if (
		body != player
		or is_transitioning
		or current_room_index != from_room
		or room_enemies_remaining[from_room] > 0
	):
		return

	_transition_to_room(destination_room, direction)


func _transition_to_room(destination_room: int, direction: Vector2i) -> void:
	is_transitioning = true
	player.velocity = Vector2.ZERO
	player.set_physics_process(false)
	transition_fade.modulate.a = 0.0
	transition_fade.show()

	var fade_in := create_tween()
	fade_in.tween_property(transition_fade, "modulate:a", 1.0, 0.18)
	await fade_in.finished

	current_room_index = destination_room
	minimap.visit_room(destination_room)
	var arrival_door_direction := -direction
	var arrival_cell: Vector2i = room_door_cells[
		destination_room
	][arrival_door_direction]
	player.global_position = (
		_actor_position_for_cell(arrival_cell)
		+ Vector2(direction) * CELL_SIZE * 1.15
	)

	_configure_camera_for_room(destination_room)
	_spawn_room_enemies(destination_room)
	_update_room_ui()
	await get_tree().process_frame
	camera.reset_smoothing()

	var fade_out := create_tween()
	fade_out.tween_property(transition_fade, "modulate:a", 0.0, 0.2)
	await fade_out.finished

	transition_fade.hide()
	player.set_physics_process(true)
	is_transitioning = false


func _spawn_room_enemies(room_index: int) -> void:
	if spawned_rooms.has(room_index):
		return

	spawned_rooms[room_index] = true
	if room_types[room_index] == ROOM_TYPE_SPECIAL:
		_spawn_special_room_reward(room_index)
		return

	for spawn_index in range(enemy_spawn_cells[room_index].size()):
		var spawn_cell: Vector2i = enemy_spawn_cells[room_index][spawn_index]
		var use_ranged_enemy := (
			spawn_index == 0
			and (
				room_types[room_index] == ROOM_TYPE_FINAL
				or (room_index > 0 and room_index % 2 == 1)
			)
		)
		var enemy_scene := (
			RANGED_ENEMY_SCENE if use_ranged_enemy else ENEMY_SCENE
		)
		var enemy := enemy_scene.instantiate() as CharacterBody2D
		enemies.add_child(enemy)
		enemy.set_meta("room_index", room_index)
		enemy.global_position = _actor_position_for_cell(spawn_cell)
		enemy.connect("died", _on_enemy_died.bind(room_index, enemy))


func _spawn_special_room_reward(room_index: int) -> void:
	if special_rewarded_rooms.has(room_index):
		return

	special_rewarded_rooms[room_index] = true
	var reward_cell := _find_safe_cell(
		room_index,
		_room_center_cell(room_index)
	)
	var pickup := HEALTH_PICKUP_SCENE.instantiate() as Area2D
	pickup.set("heal_amount", health_pickup_amount)
	pickups.add_child(pickup)
	pickup.global_position = (
		_actor_position_for_cell(reward_cell) + Vector2(0.0, 50.0)
	)


func _on_enemy_died(room_index: int, defeated_enemy: Node2D) -> void:
	room_enemies_remaining[room_index] = maxi(
		room_enemies_remaining[room_index] - 1,
		0
	)
	remaining_enemies = maxi(remaining_enemies - 1, 0)
	_refresh_room_doors(room_index)
	_update_enemy_counter()

	if room_enemies_remaining[room_index] == 0:
		_try_drop_room_reward(
			room_index,
			defeated_enemy.global_position + Vector2(0.0, 50.0)
		)

	if room_index == current_room_index:
		_update_room_ui()

	if remaining_enemies == 0:
		_complete_floor()


func _try_drop_room_reward(room_index: int, drop_position: Vector2) -> void:
	if rewarded_rooms.has(room_index):
		return

	rewarded_rooms[room_index] = true

	if rng.randf() > health_drop_chance:
		return

	var pickup := HEALTH_PICKUP_SCENE.instantiate() as Area2D
	pickup.set("heal_amount", health_pickup_amount)
	pickups.add_child(pickup)
	pickup.global_position = drop_position


func _update_enemy_counter() -> void:
	enemy_counter_label.text = "Inimigos: " + str(remaining_enemies)


func _update_room_ui() -> void:
	var room_enemy_count := room_enemies_remaining[current_room_index]
	var room_type_name := _room_type_display_name(
		room_types[current_room_index]
	)
	var status := (
		"%d inimigo(s)" % room_enemy_count
		if room_enemy_count > 0
		else (
			"Saida aberta"
			if exit_is_available and current_room_index == final_room_index
			else "Limpa"
		)
	)
	room_label.text = "%s • %d/%d • %s" % [
		room_type_name,
		current_room_index + 1,
		generated_room_count,
		status,
	]


func _room_type_display_name(room_type: String) -> String:
	match room_type:
		ROOM_TYPE_START:
			return "INICIO"
		ROOM_TYPE_SPECIAL:
			return "SANTUARIO"
		ROOM_TYPE_FINAL:
			return "SALA FINAL"
		_:
			return "COMBATE"


func _complete_floor() -> void:
	if (
		floor_is_cleared
		or remaining_enemies > 0
		or final_room_index < 0
		or room_enemies_remaining[final_room_index] > 0
	):
		return

	floor_is_cleared = true
	_spawn_floor_exit()
	floor_cleared_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	floor_cleared_label.text = "SAIDA LIBERADA NA SALA FINAL!"
	floor_cleared_label.show()

	var tween := create_tween()
	tween.tween_property(floor_cleared_label, "modulate:a", 1.0, 0.3)
	tween.tween_interval(2.0)
	tween.tween_property(floor_cleared_label, "modulate:a", 0.0, 0.5)


func _spawn_floor_exit() -> void:
	if exit_is_available or is_instance_valid(floor_exit):
		return

	floor_exit_cell = _find_safe_cell(
		final_room_index,
		_room_center_cell(final_room_index) + Vector2i(0, 4)
	)
	floor_exit = FLOOR_EXIT_SCENE.instantiate() as Area2D
	exits.add_child(floor_exit)
	floor_exit.global_position = (
		Vector2(floor_exit_cell * CELL_SIZE)
		+ Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5)
	)
	floor_exit.connect("entered", _on_floor_exit_entered)
	exit_is_available = true
	minimap.set_exit_available(final_room_index, true)
	_update_room_ui()


func _on_floor_exit_entered(body: Node2D) -> void:
	if (
		body != player
		or not exit_is_available
		or run_is_complete
		or remaining_enemies > 0
		or current_room_index != final_room_index
	):
		return

	_finish_run()


func _finish_run() -> void:
	run_is_complete = true
	is_transitioning = true
	player.velocity = Vector2.ZERO
	player.set_physics_process(false)
	victory_details.text = (
		"Seed %d  -  %d salas exploradas" % [
			generation_seed,
			generated_room_count,
		]
	)
	victory_overlay.modulate.a = 0.0
	victory_overlay.show()

	var tween := create_tween()
	tween.tween_property(victory_overlay, "modulate:a", 1.0, 0.35)


func _validate_floor() -> void:
	if generated_room_count < 5 or generated_room_count > 8:
		push_error("O andar deve possuir entre 5 e 8 salas.")

	var graph_visited: Dictionary = {0: true}
	var graph_pending: Array[int] = [0]
	var graph_index := 0

	while graph_index < graph_pending.size():
		var room_index := graph_pending[graph_index]
		graph_index += 1

		for destination in room_connections[room_index].values():
			if not graph_visited.has(destination):
				graph_visited[destination] = true
				graph_pending.append(destination)

	if graph_visited.size() != generated_room_count:
		push_error("O grafo do andar possui salas desconectadas.")

	if final_room_index <= 0:
		push_error("A sala final deve ser diferente da sala inicial.")
	elif room_distances[final_room_index] != room_distances.max():
		push_error("A sala final deve estar na maior distancia da inicial.")

	if (
		special_room_index <= 0
		or special_room_index == final_room_index
	):
		push_error("O andar deve possuir uma sala especial distinta.")

	for room_index in range(generated_room_count):
		_validate_room_navigation(room_index)

	print(
		"Andar 1 gerado | seed=", generation_seed,
		" | salas=", generated_room_count,
		" | conexões=", _connection_count(),
		" | final=", final_room_index + 1,
		" | distancia=", room_distances[final_room_index]
	)


func _validate_room_navigation(room_index: int) -> void:
	var start := _find_safe_cell(room_index, _room_center_cell(room_index))
	var pending: Array[Vector2i] = [start]
	var visited: Dictionary = {start: true}
	var next_index := 0

	while next_index < pending.size():
		var cell := pending[next_index]
		next_index += 1

		for direction in _cardinal_directions():
			var neighbor := cell + direction

			if (
				room_cells[room_index].has(neighbor)
				and not obstacle_cells.has(neighbor)
				and not visited.has(neighbor)
			):
				visited[neighbor] = true
				pending.append(neighbor)

	for door_cell in room_door_cells[room_index].values():
		if not visited.has(door_cell):
			push_error("Porta inacessível na sala " + str(room_index + 1))

	for spawn_cell in enemy_spawn_cells[room_index]:
		if not visited.has(spawn_cell):
			push_error("Spawn inacessível na sala " + str(room_index + 1))


func _connection_count() -> int:
	var directed_connection_count := 0

	for connections in room_connections:
		directed_connection_count += connections.size()

	return int(directed_connection_count * 0.5)
