extends Node2D

const CELL_SIZE := 64
const ATLAS_TILE_SIZE := Vector2i(32, 32)
const ROOM_GRID_SPACING := Vector2i(34, 24)
const MAP_ORIGIN := Vector2i(120, 100)
const FLOOR_TEXTURE: Texture2D = preload(
	"res://assets/sprites/map/dungeon/dungeon_tiles_32px.png"
)
const ENEMY_SCENE: PackedScene = preload("res://actors/enemies/enemy.tscn")
const RANGED_ENEMY_SCENE: PackedScene = preload(
	"res://actors/enemies/ranged_enemy.tscn"
)
const HEALTH_PICKUP_SCENE: PackedScene = preload(
	"res://items/pickups/health_pickup.tscn"
)
const RELIC_PICKUP_SCENE: PackedScene = preload(
	"res://items/relics/relic_pickup.tscn"
)
const KEY_PICKUP_SCENE: PackedScene = preload(
	"res://items/pickups/key_pickup.tscn"
)
const TREASURE_CHEST_SCENE: PackedScene = preload(
	"res://items/chests/treasure_chest.tscn"
)
const FLOOR_EXIT_SCENE: PackedScene = preload(
	"res://world/interactables/floor_exit.tscn"
)
const COMBAT_FEEDBACK = preload("res://combat/combat_feedback.gd")
const RELIC_CATALOG = preload("res://items/relics/relic_catalog.gd")
const DOOR_LOCKED_COLOR := Color(0.75, 0.16, 0.12, 0.95)
const DOOR_OPEN_COLOR := Color(0.95, 0.67, 0.2, 0.95)
const ROOM_TYPE_START := "start"
const ROOM_TYPE_NORMAL := "normal"
const ROOM_TYPE_SPECIAL := "special"
const ROOM_TYPE_TREASURE := "treasure"
const ROOM_TYPE_FINAL := "final"
const ENEMY_TYPE_MELEE := "melee"
const ENEMY_TYPE_RANGED := "ranged"
const LARGE_ROOM_CHANCE := 0.22
const MAXIMUM_LARGE_ROOMS := 2
const MINIMUM_SCREEN_ROOM_SIZE := Vector2i(16, 10)

@export_group("Generation")
@export var randomize_layout: bool = true
@export var fixed_seed: int = 12345
@export_range(5, 8, 1) var minimum_rooms: int = 5
@export_range(5, 8, 1) var maximum_rooms: int = 8

@export_group("Room Rewards")
@export_range(0.0, 1.0, 0.05) var health_drop_chance: float = 0.35
@export_range(1, 1000, 1) var health_pickup_amount: int = 18
@export_range(0.0, 1.0, 0.05) var key_drop_chance: float = 0.3
@export_range(1, 10, 1) var key_pickup_amount: int = 1

@export_group("Treasure Chests")
@export_range(0.0, 100.0, 1.0) var wood_chest_weight: float = 60.0
@export_range(0.0, 100.0, 1.0) var silver_chest_weight: float = 30.0
@export_range(0.0, 100.0, 1.0) var red_chest_weight: float = 10.0
@export_range(0.0, 1.0, 0.05) var wood_chest_health_chance: float = 0.55
@export_range(0.0, 1.0, 0.05) var upgraded_rarity_chance: float = 0.8

@export_group("Encounter Waves")
@export_range(0.05, 2.0, 0.05) var wave_spawn_delay: float = 0.55

var rng := RandomNumberGenerator.new()
var generation_seed: int
var generated_room_count: int
var floor_cells: Dictionary = {}
var obstacle_cells: Dictionary = {}
var room_grid_positions: Array[Vector2i] = []
var room_bounds: Array[Rect2i] = []
var room_cells: Array = []
var large_room_indices: Dictionary = {}
var room_connections: Array = []
var room_door_cells: Array = []
var room_types: Array[String] = []
var room_distances: Array[int] = []
var open_edges: Dictionary = {}
var obstacle_rects: Array[Rect2i] = []
var enemy_spawn_cells: Array = []
var room_encounter_waves: Array = []
var room_current_wave: Array[int] = []
var room_active_enemies: Array[int] = []
var room_wave_transitioning: Array[bool] = []
var room_encounter_complete: Array[bool] = []
var room_enemies_remaining: Array[int] = []
var spawned_rooms: Dictionary = {}
var rewarded_rooms: Dictionary = {}
var special_rewarded_rooms: Dictionary = {}
var available_relic_ids: Array[String] = []
var spawned_relic_ids: Array[String] = []
var door_entries: Array[Dictionary] = []
var current_room_index: int = 0
var final_room_index: int = -1
var special_room_index: int = -1
var treasure_room_index: int = -1
var keys_spawned: int = 0
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
@onready var relics: Node2D = $Relics
@onready var keys: Node2D = $Keys
@onready var chests: Node2D = $Chests
@onready var exits: Node2D = $Exits
@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Player/Camera2D
@onready var hud = $UI
@onready var enemy_counter_label: Label = $UI/EnemyCounterLabel
@onready var room_label: Label = $UI/RoomLabel
@onready var seed_label: Label = $UI/SeedLabel
@onready var floor_cleared_label: Label = $UI/FloorClearedLabel
@onready var wave_label: Label = $UI/WaveLabel
@onready var transition_fade: ColorRect = $UI/TransitionFade
@onready var victory_overlay: ColorRect = $UI/VictoryOverlay
@onready var victory_details: Label = $UI/VictoryOverlay/VictoryDetails
@onready var minimap = $UI/MinimapPanel/Minimap


func _ready() -> void:
	hud.bind_health(player.health_component)
	hud.bind_relics(player.relic_component)
	hud.bind_inventory(player.run_inventory)
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
	wave_label.hide()
	floor_cleared_label.hide()
	seed_label.text = tr("HUD_SEED") % generation_seed
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
	large_room_indices.clear()
	room_connections.clear()
	room_door_cells.clear()
	room_types.clear()
	room_distances.clear()
	open_edges.clear()
	obstacle_rects.clear()
	enemy_spawn_cells.clear()
	room_encounter_waves.clear()
	room_current_wave.clear()
	room_active_enemies.clear()
	room_wave_transitioning.clear()
	room_encounter_complete.clear()
	room_enemies_remaining.clear()
	spawned_rooms.clear()
	rewarded_rooms.clear()
	special_rewarded_rooms.clear()
	available_relic_ids = RELIC_CATALOG.get_all_ids()
	spawned_relic_ids.clear()
	final_room_index = -1
	special_room_index = -1
	treasure_room_index = -1
	keys_spawned = 0
	floor_is_cleared = false
	exit_is_available = false
	run_is_complete = false

	var minimum := mini(minimum_rooms, maximum_rooms)
	var maximum := maxi(minimum_rooms, maximum_rooms)
	generated_room_count = rng.randi_range(minimum, maximum)

	_generate_room_graph()
	_assign_room_roles()
	_select_large_rooms()
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

	var treasure_candidates: Array[int] = []
	for room_index in range(1, generated_room_count):
		if room_index in [final_room_index, special_room_index]:
			continue
		if room_connections[room_index].size() == 1:
			treasure_candidates.append(room_index)

	if treasure_candidates.is_empty():
		for room_index in range(1, generated_room_count):
			if room_index not in [final_room_index, special_room_index]:
				treasure_candidates.append(room_index)

	treasure_room_index = treasure_candidates[
		rng.randi_range(0, treasure_candidates.size() - 1)
	]
	room_types[treasure_room_index] = ROOM_TYPE_TREASURE


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


func _select_large_rooms() -> void:
	var candidates: Array[int] = []

	for room_index in range(1, generated_room_count):
		candidates.append(room_index)

	for candidate_index in range(candidates.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, candidate_index)
		var candidate := candidates[candidate_index]
		candidates[candidate_index] = candidates[swap_index]
		candidates[swap_index] = candidate
	for room_index in candidates:
		if (
			large_room_indices.size() < MAXIMUM_LARGE_ROOMS
			and rng.randf() < LARGE_ROOM_CHANCE
		):
			large_room_indices[room_index] = true

	# Every floor has one standout room without letting large rooms dominate it.
	if large_room_indices.is_empty() and not candidates.is_empty():
		large_room_indices[candidates[0]] = true


func _room_size(room_index: int) -> Vector2i:
	var screen_size := _screen_room_size()

	if large_room_indices.has(room_index):
		return Vector2i(
			screen_size.x + rng.randi_range(3, 6),
			screen_size.y + rng.randi_range(2, 4)
		)

	return Vector2i(
		screen_size.x - rng.randi_range(0, 2),
		screen_size.y - rng.randi_range(0, 1)
	)


func _screen_room_size() -> Vector2i:
	var viewport_size := get_viewport_rect().size
	return Vector2i(
		maxi(MINIMUM_SCREEN_ROOM_SIZE.x, roundi(viewport_size.x / CELL_SIZE)),
		maxi(MINIMUM_SCREEN_ROOM_SIZE.y, roundi(viewport_size.y / CELL_SIZE))
	)


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
	room_encounter_waves.resize(generated_room_count)
	room_current_wave.resize(generated_room_count)
	room_active_enemies.resize(generated_room_count)
	room_wave_transitioning.resize(generated_room_count)
	room_encounter_complete.resize(generated_room_count)
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
		var waves := _build_room_encounter(room_index)
		room_encounter_waves[room_index] = waves
		room_current_wave[room_index] = -1
		room_active_enemies[room_index] = 0
		room_wave_transitioning[room_index] = false
		room_encounter_complete[room_index] = waves.is_empty()

		var encounter_enemy_count := 0
		var maximum_wave_size := 0
		for wave in waves:
			encounter_enemy_count += wave.size()
			maximum_wave_size = maxi(maximum_wave_size, wave.size())

		var center := _room_center_cell(room_index)
		var reserved: Dictionary = {}
		var spawns: Array[Vector2i] = []

		for spawn_index in range(maximum_wave_size):
			var preferred: Vector2i = center + offsets[spawn_index % offsets.size()]
			var spawn := _find_safe_cell(room_index, preferred, reserved)
			spawns.append(spawn)
			reserved[spawn] = true

		enemy_spawn_cells[room_index] = spawns
		room_enemies_remaining[room_index] = encounter_enemy_count
		remaining_enemies += encounter_enemy_count


func _build_room_encounter(room_index: int) -> Array:
	if room_types[room_index] in [
		ROOM_TYPE_START, ROOM_TYPE_SPECIAL, ROOM_TYPE_TREASURE
	]:
		return []

	if room_types[room_index] == ROOM_TYPE_FINAL:
		return [
			[ENEMY_TYPE_MELEE, ENEMY_TYPE_MELEE],
			[ENEMY_TYPE_RANGED, ENEMY_TYPE_MELEE],
			[ENEMY_TYPE_RANGED, ENEMY_TYPE_MELEE, ENEMY_TYPE_MELEE],
		]

	var distance := room_distances[room_index]
	var wave_count := 1 if distance <= 1 else 2
	var waves: Array = []

	for wave_index in range(wave_count):
		var enemy_count := clampi(
			1 + int((distance + wave_index) / 2),
			1,
			3
		)
		var wave: Array[String] = []

		for enemy_index in range(enemy_count):
			var can_use_ranged := distance + wave_index >= 2
			var use_ranged := (
				can_use_ranged
				and enemy_index == 0
				and (room_index + wave_index) % 2 == 1
			)
			wave.append(
				ENEMY_TYPE_RANGED if use_ranged else ENEMY_TYPE_MELEE
			)

		waves.append(wave)

	return waves


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
	if room_types[room_index] == ROOM_TYPE_TREASURE:
		_spawn_treasure_room_chest(room_index)
		return

	if room_encounter_waves[room_index].is_empty():
		room_encounter_complete[room_index] = true
		return

	_spawn_next_room_wave(room_index)


func _spawn_next_room_wave(room_index: int) -> void:
	if (
		room_wave_transitioning[room_index]
		or room_encounter_complete[room_index]
		or room_active_enemies[room_index] > 0
	):
		return

	var next_wave_index := room_current_wave[room_index] + 1
	var waves: Array = room_encounter_waves[room_index]
	if next_wave_index >= waves.size():
		room_encounter_complete[room_index] = true
		return

	room_current_wave[room_index] = next_wave_index
	room_wave_transitioning[room_index] = true
	if room_index == current_room_index:
		_show_wave_banner(next_wave_index + 1, waves.size())
		_update_room_ui()

	await get_tree().create_timer(wave_spawn_delay).timeout
	if not is_inside_tree() or room_encounter_complete[room_index]:
		return

	var wave: Array = waves[next_wave_index]
	room_active_enemies[room_index] = wave.size()
	for enemy_index in range(wave.size()):
		_spawn_wave_enemy(
			room_index,
			enemy_index,
			wave[enemy_index]
		)

	room_wave_transitioning[room_index] = false
	if room_index == current_room_index:
		_update_room_ui()


func _spawn_wave_enemy(
	room_index: int,
	spawn_index: int,
	enemy_type: String
) -> void:
	var spawn_cell: Vector2i = enemy_spawn_cells[room_index][spawn_index]
	var enemy_scene := (
		RANGED_ENEMY_SCENE
		if enemy_type == ENEMY_TYPE_RANGED
		else ENEMY_SCENE
	)
	var spawn_position := _actor_position_for_cell(spawn_cell)
	COMBAT_FEEDBACK.spawn_impact_particles(
		get_tree(),
		spawn_position + Vector2(0.0, 50.0),
		Vector2.UP,
		Color(0.72, 0.25, 1.0, 1.0),
		10,
		"WaveSpawnParticles"
	)

	var enemy := enemy_scene.instantiate() as CharacterBody2D
	enemies.add_child(enemy)
	enemy.set_meta("room_index", room_index)
	enemy.set_meta("wave_index", room_current_wave[room_index])
	enemy.global_position = spawn_position
	enemy.connect("died", _on_enemy_died.bind(room_index, enemy))


func _show_wave_banner(wave_number: int, total_waves: int) -> void:
	wave_label.text = tr("HUD_WAVE") % [wave_number, total_waves]
	wave_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	wave_label.show()

	var tween := create_tween()
	tween.tween_property(wave_label, "modulate:a", 1.0, 0.12)
	tween.tween_interval(maxf(wave_spawn_delay, 0.3))
	tween.tween_property(wave_label, "modulate:a", 0.0, 0.22)
	tween.tween_callback(wave_label.hide)


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

	var relic_id := _take_random_relic_id()
	if relic_id.is_empty():
		return

	var relic_cell := _find_safe_cell(
		room_index,
		_room_center_cell(room_index) + Vector2i(3, 0),
		{reward_cell: true}
	)
	var relic := RELIC_PICKUP_SCENE.instantiate() as Area2D
	relic.call("configure", relic_id)
	relics.add_child(relic)
	relic.global_position = (
		_actor_position_for_cell(relic_cell) + Vector2(0.0, 50.0)
	)


func _take_random_relic_id(rarities: Array[String] = []) -> String:
	var candidates: Array[String] = []
	for relic_id in available_relic_ids:
		var relic_data: Dictionary = RELIC_CATALOG.get_relic(relic_id)
		var matches_rarity: bool = (
			rarities.is_empty()
			or relic_data.get("rarity", "common") in rarities
		)
		if not player.relic_component.has_relic(relic_id) and matches_rarity:
			candidates.append(relic_id)

	if candidates.is_empty():
		return ""

	var relic_id := candidates[rng.randi_range(0, candidates.size() - 1)]
	available_relic_ids.erase(relic_id)
	spawned_relic_ids.append(relic_id)
	return relic_id


func _spawn_treasure_room_chest(room_index: int) -> void:
	if special_rewarded_rooms.has(room_index):
		return

	special_rewarded_rooms[room_index] = true
	var chest_cell := _find_safe_cell(
		room_index, _room_center_cell(room_index)
	)
	var chest := TREASURE_CHEST_SCENE.instantiate() as TreasureChest
	chest.configure(_roll_chest_tier())
	chests.add_child(chest)
	chest.global_position = (
		_actor_position_for_cell(chest_cell) + Vector2(0.0, 50.0)
	)
	chest.opened.connect(_on_treasure_chest_opened)


func _on_treasure_chest_opened(chest: TreasureChest) -> void:
	var relic_id := _take_chest_relic_id(chest.chest_tier)
	if relic_id.is_empty():
		_spawn_chest_health_reward(chest.global_position)
		return

	var relic := RELIC_PICKUP_SCENE.instantiate() as Area2D
	relic.call("configure", relic_id)
	relics.add_child(relic)
	relic.global_position = chest.global_position + Vector2(0.0, 58.0)


func _roll_chest_tier() -> int:
	var total_weight := (
		wood_chest_weight + silver_chest_weight + red_chest_weight
	)
	if total_weight <= 0.0:
		return TreasureChest.ChestTier.WOOD

	var roll := rng.randf_range(0.0, total_weight)
	if roll < wood_chest_weight:
		return TreasureChest.ChestTier.WOOD
	if roll < wood_chest_weight + silver_chest_weight:
		return TreasureChest.ChestTier.SILVER
	return TreasureChest.ChestTier.RED


func _take_chest_relic_id(chest_tier: int) -> String:
	if (
		chest_tier == TreasureChest.ChestTier.WOOD
		and rng.randf() < wood_chest_health_chance
	):
		return ""

	var preferred_rarity := "common"
	var fallback_rarities: Array[String] = []
	match chest_tier:
		TreasureChest.ChestTier.SILVER:
			preferred_rarity = (
				"uncommon" if rng.randf() < upgraded_rarity_chance else "common"
			)
			fallback_rarities = ["uncommon", "common"]
		TreasureChest.ChestTier.RED:
			preferred_rarity = (
				"rare" if rng.randf() < upgraded_rarity_chance else "uncommon"
			)
			fallback_rarities = ["rare", "uncommon", "common"]
		_:
			fallback_rarities = ["common"]

	var relic_id := _take_random_relic_id([preferred_rarity])
	if not relic_id.is_empty():
		return relic_id

	for rarity in fallback_rarities:
		if rarity == preferred_rarity:
			continue
		relic_id = _take_random_relic_id([rarity])
		if not relic_id.is_empty():
			return relic_id

	return ""


func _spawn_chest_health_reward(chest_position: Vector2) -> void:
	var health_reward := HEALTH_PICKUP_SCENE.instantiate() as Area2D
	health_reward.set("heal_amount", health_pickup_amount)
	pickups.add_child(health_reward)
	health_reward.global_position = chest_position + Vector2(0.0, 58.0)


func _on_enemy_died(room_index: int, defeated_enemy: Node2D) -> void:
	room_enemies_remaining[room_index] = maxi(
		room_enemies_remaining[room_index] - 1,
		0
	)
	room_active_enemies[room_index] = maxi(
		room_active_enemies[room_index] - 1,
		0
	)
	remaining_enemies = maxi(remaining_enemies - 1, 0)
	_refresh_room_doors(room_index)
	_update_enemy_counter()

	if (
		room_active_enemies[room_index] == 0
		and room_enemies_remaining[room_index] > 0
	):
		_spawn_next_room_wave(room_index)
	elif room_enemies_remaining[room_index] == 0:
		room_encounter_complete[room_index] = true
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
	_try_drop_key(drop_position + Vector2(-24.0, 0.0))

	if rng.randf() > health_drop_chance:
		return

	var pickup := HEALTH_PICKUP_SCENE.instantiate() as Area2D
	pickup.set("heal_amount", health_pickup_amount)
	pickups.add_child(pickup)
	pickup.global_position = drop_position + Vector2(24.0, 0.0)


func _try_drop_key(drop_position: Vector2) -> void:
	var is_guaranteed_first_key := keys_spawned == 0
	if not is_guaranteed_first_key and rng.randf() > key_drop_chance:
		return

	var key := KEY_PICKUP_SCENE.instantiate() as Area2D
	key.set("key_amount", key_pickup_amount)
	keys.add_child(key)
	key.global_position = drop_position
	keys_spawned += key_pickup_amount


func _update_enemy_counter() -> void:
	enemy_counter_label.text = tr("HUD_ENEMY_COUNT") % remaining_enemies


func _update_room_ui() -> void:
	var room_type_name := _room_type_display_name(
		room_types[current_room_index]
	)
	var status := _room_encounter_status(current_room_index)
	room_label.text = tr("HUD_ROOM_SUMMARY") % [
		room_type_name,
		current_room_index + 1,
		generated_room_count,
		status,
	]


func _room_encounter_status(room_index: int) -> String:
	if exit_is_available and room_index == final_room_index:
		return tr("ROOM_STATUS_EXIT_OPEN")

	if room_encounter_complete[room_index]:
		return tr("ROOM_STATUS_CLEARED")

	if room_wave_transitioning[room_index]:
		return tr("ROOM_STATUS_NEXT_WAVE")

	if not spawned_rooms.has(room_index):
		return tr("ROOM_STATUS_WAITING")

	var wave_number := room_current_wave[room_index] + 1
	var total_waves: int = room_encounter_waves[room_index].size()
	return tr("ROOM_STATUS_WAVE") % [
		wave_number,
		total_waves,
		room_active_enemies[room_index],
	]


func _room_type_display_name(room_type: String) -> String:
	match room_type:
		ROOM_TYPE_START:
			return tr("ROOM_TYPE_START")
		ROOM_TYPE_SPECIAL:
			return tr("ROOM_TYPE_SANCTUARY")
		ROOM_TYPE_TREASURE:
			return tr("ROOM_TYPE_TREASURE")
		ROOM_TYPE_FINAL:
			return tr("ROOM_TYPE_FINAL")
		_:
			return tr("ROOM_TYPE_COMBAT")


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
	floor_cleared_label.text = tr("HUD_FLOOR_EXIT_UNLOCKED")
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
		tr("HUD_VICTORY_DETAILS") % [
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
		push_error("The floor must contain between 5 and 8 rooms.")

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
		push_error("The floor graph contains disconnected rooms.")

	if final_room_index <= 0:
		push_error("The final room must differ from the starting room.")
	elif room_distances[final_room_index] != room_distances.max():
		push_error("The final room must be farthest from the starting room.")

	if (
		special_room_index <= 0
		or special_room_index == final_room_index
	):
		push_error("The floor must contain a distinct sanctuary room.")

	if (
		treasure_room_index <= 0
		or treasure_room_index in [final_room_index, special_room_index]
	):
		push_error("The floor must contain a distinct treasure room.")

	for room_index in range(generated_room_count):
		_validate_room_navigation(room_index)

	print(
		"Floor 1 generated | seed=", generation_seed,
		" | rooms=", generated_room_count,
		" | connections=", _connection_count(),
		" | final=", final_room_index + 1,
		" | distance=", room_distances[final_room_index]
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
			push_error("Unreachable door in room " + str(room_index + 1))

	for spawn_cell in enemy_spawn_cells[room_index]:
		if not visited.has(spawn_cell):
			push_error("Unreachable spawn in room " + str(room_index + 1))


func _connection_count() -> int:
	var directed_connection_count := 0

	for connections in room_connections:
		directed_connection_count += connections.size()

	return int(directed_connection_count * 0.5)
