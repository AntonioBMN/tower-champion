extends SceneTree

const PLAYER_SCENE: PackedScene = preload("res://actors/player/player.tscn")
const RANGED_ENEMY_SCENE: PackedScene = preload(
	"res://actors/enemies/ranged_enemy.tscn"
)

var failures: int = 0
var ranged_enemy_died: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node2D.new()
	world.name = "RangedEnemyTestWorld"
	root.add_child(world)
	current_scene = world

	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	player.position = Vector2.ZERO
	world.add_child(player)
	var line_of_sight_wall := _create_test_wall()
	world.add_child(line_of_sight_wall)

	var ranged_enemy := RANGED_ENEMY_SCENE.instantiate() as CharacterBody2D
	ranged_enemy.position = Vector2(340.0, 0.0)
	world.add_child(ranged_enemy)
	ranged_enemy.connect("died", _on_ranged_enemy_died)

	var player_health := player.get_node("HealthComponent") as HealthComponent
	var ranged_health := ranged_enemy.get_node("HealthComponent") as HealthComponent
	var initial_enemy_position := ranged_enemy.position
	_expect(
		is_equal_approx(float(ranged_enemy.get("attack_interval")), 1.75),
		"ranged enemy should use the slower attack cadence"
	)
	_expect(
		is_equal_approx(float(ranged_enemy.get("entry_grace_duration")), 0.75)
		and float(ranged_enemy.get("attack_grace_remaining")) > 0.0,
		"ranged enemy should start with a safe room-entry grace period"
	)
	_expect(
		is_equal_approx(float(ranged_enemy.get("attack_windup")), 0.3),
		"ranged attacks should expose a readable wind-up"
	)
	_expect(
		is_equal_approx(
			ranged_enemy.get_node("ShootCooldown").wait_time,
			float(ranged_enemy.get("attack_interval"))
		),
		"ranged cooldown should follow its configured attack interval"
	)
	_expect(
		ranged_health.max_health == int(player.get("attack_damage")),
		"ranged enemy should still die from one base sword hit"
	)

	await create_timer(1.3).timeout
	_expect(
		player_health.current_health == player_health.max_health,
		"ranged enemy should not shoot through walls"
	)

	ranged_enemy.set_physics_process(false)
	line_of_sight_wall.queue_free()
	await physics_frame
	await physics_frame
	ranged_enemy.call("_begin_attack")
	await create_timer(0.1).timeout
	_expect(
		ranged_enemy.get("is_winding_up"),
		"ranged enemy should enter a warning state before shooting"
	)
	_expect(
		_find_projectile(world) == null,
		"projectile should not exist during the attack warning"
	)
	_expect(
		world.get_node_or_null("RangedAttackTelegraph") != null,
		"attack warning should provide visual feedback"
	)
	await create_timer(0.25).timeout
	_expect(
		_find_projectile(world) != null,
		"projectile should spawn after the warning finishes"
	)
	ranged_enemy.set_physics_process(true)
	await create_timer(1.0).timeout

	_expect(
		player_health.current_health
		== player_health.max_health - int(ranged_enemy.get("projectile_damage")),
		"ranged projectile should damage the player once"
	)
	_expect(
		ranged_enemy.position.distance_to(initial_enemy_position) < 8.0,
		"ranged enemy should hold its preferred distance"
	)

	ranged_health.take_damage(ranged_health.max_health)
	await process_frame
	_expect(ranged_enemy_died, "ranged enemy should emit its death event")

	if failures == 0:
		print("PASS: ranged enemy smoke test")

	quit(failures)


func _on_ranged_enemy_died() -> void:
	ranged_enemy_died = true


func _find_projectile(world: Node) -> EnemyProjectile:
	for child in world.get_children():
		if child is EnemyProjectile:
			return child
	return null


func _create_test_wall() -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.position = Vector2(170.0, 50.0)
	wall.collision_layer = 8

	var shape := RectangleShape2D.new()
	shape.size = Vector2(24.0, 180.0)

	var collision := CollisionShape2D.new()
	collision.shape = shape
	wall.add_child(collision)
	return wall


func _expect(condition: bool, message: String) -> void:
	if condition:
		return

	failures += 1
	push_error("FAIL: " + message)
