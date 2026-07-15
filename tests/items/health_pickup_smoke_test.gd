extends SceneTree

const FIRST_FLOOR_SCENE: PackedScene = preload(
	"res://world/floors/first_floor.tscn"
)

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var floor_scene := FIRST_FLOOR_SCENE.instantiate()
	floor_scene.set("health_drop_chance", 1.0)
	root.add_child(floor_scene)
	current_scene = floor_scene
	await process_frame

	var player := floor_scene.get_node("Player") as CharacterBody2D
	var health := player.get_node("HealthComponent") as HealthComponent
	var pickups := floor_scene.get_node("Pickups") as Node2D
	var drop_position := player.global_position + Vector2(0.0, 50.0)

	floor_scene.call("_try_drop_room_reward", 0, drop_position)
	await physics_frame
	_expect(pickups.get_child_count() == 1, "cleared room should drop health")
	_expect(
		health.current_health == health.max_health,
		"health pickup should remain when player health is full"
	)

	floor_scene.call("_try_drop_room_reward", 0, drop_position)
	_expect(
		pickups.get_child_count() == 1,
		"each room should roll its reward only once"
	)

	var pickup_heal: int = floor_scene.get("health_pickup_amount")
	_expect(pickup_heal == 18, "health pickups should restore eighteen health")
	health.take_damage(pickup_heal)
	await physics_frame
	await process_frame
	_expect(
		health.current_health == health.max_health,
		"health pickup should restore its configured proportional amount"
	)
	_expect(pickups.get_child_count() == 0, "collected pickup should disappear")

	if failures == 0:
		print("PASS: room health reward smoke test")

	quit(failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return

	failures += 1
	push_error("FAIL: " + message)
