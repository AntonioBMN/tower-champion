extends SceneTree

const FIRST_FLOOR_SCENE: PackedScene = preload("res://first_floor.tscn")

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var floor_scene := FIRST_FLOOR_SCENE.instantiate()
	root.add_child(floor_scene)
	current_scene = floor_scene
	await process_frame
	await physics_frame

	var room_types: Array = floor_scene.get("room_types")
	var room_distances: Array = floor_scene.get("room_distances")
	var room_enemy_counts: Array = floor_scene.get("room_enemies_remaining")
	var final_room_index: int = floor_scene.get("final_room_index")
	var special_room_index: int = floor_scene.get("special_room_index")
	var minimap := floor_scene.get_node("UI/MinimapPanel/Minimap")

	_expect(room_types[0] == "start", "first room should be the start room")
	_expect(
		room_types[final_room_index] == "final",
		"farthest room should be marked as final"
	)
	_expect(
		room_distances[final_room_index] == room_distances.max(),
		"final room should have the maximum graph distance"
	)
	_expect(
		final_room_index != 0 and room_distances[final_room_index] > 0,
		"final room should differ from the start"
	)
	_expect(
		room_types[special_room_index] == "special",
		"floor should have a distinct special room"
	)
	_expect(
		room_enemy_counts[0] == 0
		and room_enemy_counts[special_room_index] == 0,
		"start and special rooms should not contain combat"
	)
	_expect(
		floor_scene.get("room_encounter_waves")[final_room_index].size() == 3,
		"final room should have a three-wave encounter"
	)
	_expect(
		room_enemy_counts[final_room_index] == 7,
		"final encounter should track enemies from every wave"
	)
	_expect(
		minimap.call("get_room_type", final_room_index) == "final",
		"minimap should receive the final room role"
	)

	floor_scene.call("_spawn_room_enemies", special_room_index)
	_expect(
		floor_scene.get_node("Pickups").get_child_count() == 1,
		"special room should provide a guaranteed health reward"
	)

	floor_scene.call("_complete_floor")
	_expect(
		not floor_scene.get("exit_is_available"),
		"exit should remain blocked while enemies exist"
	)

	for room_index in range(room_enemy_counts.size()):
		room_enemy_counts[room_index] = 0
	floor_scene.set("remaining_enemies", 0)
	floor_scene.call("_complete_floor")
	await process_frame

	_expect(
		floor_scene.get("exit_is_available"),
		"clearing every encounter should unlock the exit"
	)
	_expect(
		floor_scene.get_node("Exits").get_child_count() == 1,
		"unlocked floor should spawn one exit"
	)
	var exit_cell: Vector2i = floor_scene.get("floor_exit_cell")
	var room_cells: Array = floor_scene.get("room_cells")
	var obstacle_cells: Dictionary = floor_scene.get("obstacle_cells")
	_expect(
		room_cells[final_room_index].has(exit_cell)
		and not obstacle_cells.has(exit_cell),
		"floor exit should spawn on an accessible final-room cell"
	)

	minimap.call("visit_room", final_room_index)
	_expect(
		minimap.call("is_exit_marker_visible"),
		"visited final room should show the unlocked exit on the minimap"
	)

	floor_scene.set("current_room_index", final_room_index)
	var player := floor_scene.get_node("Player") as CharacterBody2D
	floor_scene.call("_on_floor_exit_entered", player)
	await process_frame
	_expect(
		floor_scene.get("run_is_complete"),
		"entering the unlocked exit should complete the run"
	)
	_expect(
		floor_scene.get_node("UI/VictoryOverlay").visible,
		"run completion should show the provisional victory screen"
	)

	var first_seed: int = floor_scene.get("generation_seed")
	var second_floor := FIRST_FLOOR_SCENE.instantiate()
	root.add_child(second_floor)
	await process_frame
	_expect(
		second_floor.get("generation_seed") != first_seed,
		"a new run should use a different random seed"
	)

	if failures == 0:
		print("PASS: first floor progression smoke test")

	quit(failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return

	failures += 1
	push_error("FAIL: " + message)
