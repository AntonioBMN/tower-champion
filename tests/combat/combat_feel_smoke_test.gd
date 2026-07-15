extends SceneTree

const PLAYER_SCENE: PackedScene = preload("res://actors/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://actors/enemies/enemy.tscn")

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node2D.new()
	world.name = "CombatFeelTestWorld"
	root.add_child(world)
	current_scene = world

	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	world.add_child(player)
	player.global_position = Vector2.ZERO
	var player_collision := player.get_node("CollisionShape2D") as CollisionShape2D
	_expect(
		player_collision.position == Vector2(0.0, 50.0),
		"player body collision should align with the center of the feet"
	)
	_expect(
		player_collision.shape is CapsuleShape2D,
		"player should use a rounded footprint to avoid catching on corners"
	)

	var enemy := ENEMY_SCENE.instantiate() as CharacterBody2D
	world.add_child(enemy)
	enemy.global_position = Vector2(70.0, 0.0)

	var enemy_health := enemy.get_node("HealthComponent") as HealthComponent
	var initial_health := enemy_health.current_health
	var sword_damage: int = player.get("attack_damage")
	_expect(sword_damage == 20, "player base sword damage should be twenty")
	_expect(enemy_health.max_health == 60, "melee enemy should have sixty health")
	player.call("perform_sword_attack")
	_expect(player.get("attack_active"), "sword swing should become active")
	_expect(
		player.get_node("AnimatedSprite2D").animation == "attack",
		"sword swing should play the attack animation"
	)
	_expect(
		player.get_node("SwingAudio").playing,
		"sword swing should play its audio feedback"
	)

	await physics_frame
	await physics_frame

	_expect(
		enemy_health.current_health == initial_health - sword_damage,
		"sword hit should still apply configured damage"
	)
	_expect(
		enemy.get("knockback_velocity").length() > 0.0,
		"sword hit should apply knockback"
	)
	_expect(
		world.get_node_or_null("SwordHitParticles") != null,
		"sword hit should spawn impact particles"
	)
	_expect(
		Engine.time_scale < 1.0,
		"first target hit should trigger hit-stop"
	)
	_expect(
		player.get_node("SwingAudio").stream != null
		and player.get_node("HitAudio").stream != null,
		"combat audio streams should be configured"
	)
	_expect(
		player.get_node("AnimatedSprite2D").sprite_frames.has_animation(
			"attack"
		),
		"player should have a sword attack animation"
	)

	player.call("try_damage_attack_target", enemy)
	_expect(
		enemy_health.current_health == initial_health - sword_damage,
		"one swing should not damage the same target twice"
	)

	await create_timer(0.2, true, false, true).timeout
	_expect(
		is_equal_approx(Engine.time_scale, 1.0),
		"hit-stop should restore the game speed"
	)

	if failures == 0:
		print("PASS: combat feel smoke test")

	Engine.time_scale = 1.0
	quit(failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return

	failures += 1
	push_error("FAIL: " + message)
