extends SceneTree

const FIRST_FLOOR_SCENE: PackedScene = preload(
	"res://world/floors/first_floor.tscn"
)

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var floor_scene := FIRST_FLOOR_SCENE.instantiate()
	root.add_child(floor_scene)
	current_scene = floor_scene
	await process_frame
	await physics_frame

	var encounters: Array = floor_scene.get("room_encounters")
	var room_enemy_counts: Array = floor_scene.get("room_enemies_remaining")
	var large_rooms: Dictionary = floor_scene.get("large_room_indices")
	var room_types: Array = floor_scene.get("room_types")
	var room_distances: Array = floor_scene.get("room_distances")
	var total_planned := 0

	for encounter in encounters:
		total_planned += encounter.size()

	_expect(
		floor_scene.get("remaining_enemies") == total_planned,
		"floor counter should include every complete room encounter"
	)
	_expect(
		floor_scene.get_node_or_null("UI/SafeFrame/WaveLabel") == null,
		"HUD should not contain wave feedback"
	)

	for room_index in large_rooms:
		var base_count := (
			5
			if room_types[room_index] == "final"
			else clampi(1 + room_distances[room_index], 2, 4)
		)
		_expect(
			encounters[room_index].size() == mini(base_count + 2, 6),
			"large combat rooms should add two enemies to one encounter"
		)

	var final_room_index: int = floor_scene.get("final_room_index")
	var final_encounter: Array = encounters[final_room_index]
	floor_scene.set("current_room_index", final_room_index)
	floor_scene.get_node("UI/SafeFrame/MinimapPanel/Minimap").call(
		"visit_room", final_room_index
	)
	floor_scene.set("is_transitioning", true)
	floor_scene.call("_spawn_room_enemies", final_room_index)
	var spawned_final_enemies := _get_room_enemies(
		floor_scene, final_room_index
	)
	for enemy in spawned_final_enemies:
		_expect(
			not enemy.is_physics_processing(),
			"enemies should remain inactive while the room transition is visible"
		)
	floor_scene.set("is_transitioning", false)
	floor_scene.call("_activate_room_combat", final_room_index)
	var ranged_grace_periods: Array[float] = []
	for enemy in spawned_final_enemies:
		_expect(
			enemy.is_physics_processing(),
			"room reveal should activate the complete encounter"
		)
		if enemy is RangedEnemy:
			ranged_grace_periods.append(
				float(enemy.get("attack_grace_remaining"))
			)
			_expect(
				float(enemy.get("attack_grace_remaining")) > 0.0,
				"ranged enemies should receive grace after the room reveal"
			)
	_expect(
		ranged_grace_periods.size() == 2
		and absf(ranged_grace_periods[1] - ranged_grace_periods[0]) >= 0.29,
		"multiple ranged enemies should stagger their first attacks"
	)

	_expect(
		_count_room_enemies(floor_scene, final_room_index)
		== final_encounter.size(),
		"entering a room should spawn its complete encounter immediately"
	)
	_expect(
		_count_ranged_enemies(floor_scene, final_room_index) == 2,
		"final encounter should combine melee and ranged threats"
	)

	var final_door_collision: CollisionShape2D
	for entry in floor_scene.get("door_entries"):
		if entry["room"] == final_room_index:
			final_door_collision = entry["collision"] as CollisionShape2D
			break

	_expect(
		is_instance_valid(final_door_collision)
		and not final_door_collision.disabled,
		"doors should remain locked during the encounter"
	)

	var first_enemy := _get_room_enemies(floor_scene, final_room_index)[0]
	_defeat_enemy(first_enemy)
	await physics_frame
	await process_frame
	_expect(
		_count_room_enemies(floor_scene, final_room_index)
		== final_encounter.size() - 1,
		"defeating an enemy should not spawn a replacement wave"
	)
	_expect(
		room_enemy_counts[final_room_index] == final_encounter.size() - 1,
		"room counter should track only the enemies currently alive"
	)

	for enemy in _get_room_enemies(floor_scene, final_room_index):
		_defeat_enemy(enemy)
	await physics_frame
	await process_frame

	_expect(
		floor_scene.get("room_encounter_complete")[final_room_index],
		"room should complete after its single encounter is defeated"
	)
	_expect(
		room_enemy_counts[final_room_index] == 0,
		"cleared room should have no pending enemies"
	)
	_expect(
		final_door_collision.disabled,
		"doors should open after the encounter"
	)
	_expect(
		not floor_scene.get("exit_is_available"),
		"clearing only the final room should not bypass other encounters"
	)

	if failures == 0:
		print("PASS: room encounter smoke test")

	quit(failures)


func _get_room_enemies(floor_scene: Node, room_index: int) -> Array[Node]:
	var result: Array[Node] = []
	for enemy in floor_scene.get_node("Enemies").get_children():
		if (
			not enemy.is_queued_for_deletion()
			and enemy.get_meta("room_index", -1) == room_index
		):
			result.append(enemy)
	return result


func _defeat_enemy(enemy: Node) -> void:
	var health := enemy.get_node("HealthComponent") as HealthComponent
	health.take_damage(health.current_health)


func _count_room_enemies(floor_scene: Node, room_index: int) -> int:
	return _get_room_enemies(floor_scene, room_index).size()


func _count_ranged_enemies(floor_scene: Node, room_index: int) -> int:
	var count := 0
	for enemy in _get_room_enemies(floor_scene, room_index):
		if (
			enemy.get_script().resource_path
			== "res://actors/enemies/ranged_enemy.gd"
		):
			count += 1
	return count


func _expect(condition: bool, message: String) -> void:
	if condition:
		return

	failures += 1
	push_error("FAIL: " + message)
