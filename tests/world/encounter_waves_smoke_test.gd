extends SceneTree

const FIRST_FLOOR_SCENE: PackedScene = preload(
	"res://world/floors/first_floor.tscn"
)

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var floor_scene := FIRST_FLOOR_SCENE.instantiate()
	floor_scene.set("wave_spawn_delay", 0.05)
	root.add_child(floor_scene)
	current_scene = floor_scene
	await process_frame
	await physics_frame

	var final_room_index: int = floor_scene.get("final_room_index")
	var waves: Array = floor_scene.get("room_encounter_waves")[
		final_room_index
	]
	var room_enemy_counts: Array = floor_scene.get("room_enemies_remaining")
	var total_planned := 0
	for room_waves in floor_scene.get("room_encounter_waves"):
		for wave in room_waves:
			total_planned += wave.size()

	_expect(waves.size() == 3, "final encounter should contain three waves")
	_expect(
		floor_scene.get("remaining_enemies") == total_planned,
		"floor counter should include enemies from future waves"
	)

	floor_scene.set("current_room_index", final_room_index)
	floor_scene.get_node("UI/MinimapPanel/Minimap").call(
		"visit_room", final_room_index
	)
	floor_scene.call("_spawn_room_enemies", final_room_index)
	_expect(
		floor_scene.get("room_wave_transitioning")[final_room_index],
		"activating a room should telegraph its first wave"
	)
	_expect(
		floor_scene.get_node("UI/WaveLabel").visible,
		"wave telegraph should be visible"
	)

	var final_door_collision: CollisionShape2D
	for entry in floor_scene.get("door_entries"):
		if entry["room"] == final_room_index:
			final_door_collision = entry["collision"] as CollisionShape2D
			break

	await create_timer(0.08).timeout
	_expect(
		floor_scene.get("room_current_wave")[final_room_index] == 0,
		"first wave should become active"
	)
	_expect(
		floor_scene.get("room_active_enemies")[final_room_index]
		== waves[0].size(),
		"active enemy count should match the first composition"
	)
	_expect(
		_count_room_enemies(floor_scene, final_room_index) == waves[0].size(),
		"first wave should spawn only its own members"
	)

	_defeat_active_enemies(floor_scene, final_room_index)
	await physics_frame
	_expect(
		room_enemy_counts[final_room_index] > 0,
		"future waves should keep the encounter incomplete"
	)
	_expect(
		is_instance_valid(final_door_collision)
		and not final_door_collision.disabled,
		"doors should remain locked between waves"
	)

	await create_timer(0.08).timeout
	_expect(
		floor_scene.get("room_current_wave")[final_room_index] == 1,
		"clearing the first wave should start the second"
	)
	_expect(
		_count_ranged_enemies(floor_scene, final_room_index) == 1,
		"second final wave should use its ranged composition"
	)

	_defeat_active_enemies(floor_scene, final_room_index)
	await create_timer(0.08).timeout
	_expect(
		floor_scene.get("room_current_wave")[final_room_index] == 2,
		"clearing the second wave should start the third"
	)
	_expect(
		floor_scene.get("room_active_enemies")[final_room_index]
		== waves[2].size(),
		"third wave should use its complete composition"
	)

	_defeat_active_enemies(floor_scene, final_room_index)
	await physics_frame
	_expect(
		floor_scene.get("room_encounter_complete")[final_room_index],
		"final room should complete only after its last wave"
	)
	_expect(
		room_enemy_counts[final_room_index] == 0,
		"final room should have no pending enemies after all waves"
	)
	_expect(
		final_door_collision.disabled,
		"doors should open after the entire encounter"
	)
	_expect(
		not floor_scene.get("exit_is_available"),
		"clearing only the final room should not bypass other encounters"
	)

	if failures == 0:
		print("PASS: encounter waves smoke test")

	quit(failures)


func _defeat_active_enemies(floor_scene: Node, room_index: int) -> void:
	for enemy in floor_scene.get_node("Enemies").get_children():
		if enemy.get_meta("room_index", -1) != room_index:
			continue

		var health := enemy.get_node("HealthComponent") as HealthComponent
		health.take_damage(health.current_health)


func _count_room_enemies(floor_scene: Node, room_index: int) -> int:
	var count := 0
	for enemy in floor_scene.get_node("Enemies").get_children():
		if (
			not enemy.is_queued_for_deletion()
			and enemy.get_meta("room_index", -1) == room_index
		):
			count += 1
	return count


func _count_ranged_enemies(floor_scene: Node, room_index: int) -> int:
	var count := 0
	for enemy in floor_scene.get_node("Enemies").get_children():
		if (
			not enemy.is_queued_for_deletion()
			and enemy.get_meta("room_index", -1) == room_index
			and enemy.get_script().resource_path
			== "res://actors/enemies/ranged_enemy.gd"
		):
			count += 1
	return count


func _expect(condition: bool, message: String) -> void:
	if condition:
		return

	failures += 1
	push_error("FAIL: " + message)
