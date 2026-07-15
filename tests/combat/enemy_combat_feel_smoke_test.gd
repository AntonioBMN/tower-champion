extends SceneTree

const PLAYER_SCENE: PackedScene = preload("res://actors/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://actors/enemies/enemy.tscn")
const RANGED_ENEMY_SCENE: PackedScene = preload(
	"res://actors/enemies/ranged_enemy.tscn"
)

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node2D.new()
	world.name = "EnemyCombatFeelTestWorld"
	root.add_child(world)
	current_scene = world

	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	world.add_child(player)
	player.global_position = Vector2(80.0, 0.0)
	var player_health := player.get_node("HealthComponent") as HealthComponent

	var melee_enemy := ENEMY_SCENE.instantiate() as CharacterBody2D
	world.add_child(melee_enemy)
	melee_enemy.global_position = Vector2.ZERO
	var initial_health := player_health.current_health
	_expect(
		int(melee_enemy.get("contact_damage")) == 12,
		"melee enemy base damage should be twelve"
	)
	var melee_hit_applied: bool = melee_enemy.call(
		"_deal_contact_damage", player
	)

	_expect(melee_hit_applied, "melee enemy should land its contact attack")
	_expect(
		player_health.current_health
		== initial_health - int(melee_enemy.get("contact_damage")),
		"melee attack should damage the player"
	)
	_expect(
		player.get("received_knockback_velocity").length() > 0.0,
		"melee attack should knock the player back"
	)
	_expect(
		melee_enemy.get_node("AnimatedSprite2D").animation == "attack",
		"melee enemy should play its attack animation"
	)
	_expect(
		melee_enemy.get_node("AttackAudio").playing,
		"melee enemy should play attack audio"
	)
	_expect(
		world.get_node_or_null("EnemyMeleeHitParticles") != null,
		"melee enemy should spawn impact particles"
	)

	await create_timer(0.06, true, false, true).timeout
	player_health.reset_health()
	player.set("received_knockback_velocity", Vector2.ZERO)

	var ranged_enemy := RANGED_ENEMY_SCENE.instantiate() as CharacterBody2D
	world.add_child(ranged_enemy)
	_expect(
		int(ranged_enemy.get("projectile_damage")) == 10,
		"ranged enemy base damage should be ten"
	)
	ranged_enemy.global_position = Vector2(320.0, 0.0)
	ranged_enemy.get_node("AimPivot").rotation = PI
	ranged_enemy.call("shoot")

	_expect(
		ranged_enemy.get_node("AnimatedSprite2D").animation == "attack",
		"ranged enemy should play its attack animation"
	)
	_expect(
		ranged_enemy.get_node("AttackAudio").playing,
		"ranged enemy should play launch audio"
	)
	_expect(
		world.get_node_or_null("RangedLaunchParticles") != null,
		"ranged enemy should spawn launch particles"
	)

	var projectile: EnemyProjectile
	for child in world.get_children():
		if child is EnemyProjectile:
			projectile = child
			break

	_expect(projectile != null, "ranged enemy should create a projectile")
	if projectile != null:
		var health_before_projectile := player_health.current_health
		projectile.call("_on_body_entered", player)
		_expect(
			player_health.current_health
			== health_before_projectile - projectile.damage,
			"ranged projectile should damage the player"
		)
		_expect(
			player.get("received_knockback_velocity").length() > 0.0,
			"ranged projectile should knock the player back"
		)
		_expect(
			world.get_node_or_null("EnemyProjectileHitParticles") != null,
			"ranged projectile should spawn impact particles"
		)
		_expect(
			world.get_node_or_null("EnemyProjectileHitAudio") != null,
			"ranged projectile should play impact audio"
		)

	_expect(
		Engine.time_scale < 1.0,
		"enemy damage should trigger player hit-stop"
	)
	await create_timer(0.08, true, false, true).timeout
	_expect(
		is_equal_approx(Engine.time_scale, 1.0),
		"enemy hit-stop should restore the game speed"
	)

	if failures == 0:
		print("PASS: enemy combat feel smoke test")

	Engine.time_scale = 1.0
	await create_timer(0.12, true, false, true).timeout
	for audio_node in world.find_children(
		"*", "AudioStreamPlayer2D", true, false
	):
		audio_node.stop()
	world.queue_free()
	await process_frame
	quit(failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return

	failures += 1
	push_error("FAIL: " + message)
