class_name RangedEnemy
extends CharacterBody2D

signal died

const PROJECTILE_SCENE: PackedScene = preload(
	"res://combat/enemy_projectile.tscn"
)
const COMBAT_FEEDBACK = preload("res://combat/combat_feedback.gd")

@export_group("Stats")
@export_range(1, 1000, 1) var max_health: int = 20

@export_group("Movement")
@export_range(10.0, 500.0, 5.0) var move_speed: float = 85.0
@export_range(80.0, 500.0, 10.0) var retreat_distance: float = 220.0
@export_range(120.0, 700.0, 10.0) var preferred_distance: float = 340.0
@export_range(200.0, 1200.0, 25.0) var activation_distance: float = 750.0
@export_range(100.0, 4000.0, 50.0) var knockback_deceleration: float = 1800.0

@export_group("Ranged Attack")
@export_range(1, 1000, 1) var projectile_damage: int = 10
@export_range(100.0, 1200.0, 10.0) var projectile_speed: float = 520.0
@export_range(0.2, 5.0, 0.05) var attack_interval: float = 1.75
@export_range(0.0, 3.0, 0.05) var entry_grace_duration: float = 0.75
@export_range(0.05, 1.0, 0.05) var attack_windup: float = 0.3
@export_range(100.0, 1000.0, 10.0) var attack_range: float = 580.0
@export_range(1, 48, 1) var launch_particle_amount: int = 10

var player: Node2D
var knockback_velocity: Vector2 = Vector2.ZERO
var attack_feedback_remaining: float = 0.0
var attack_grace_remaining: float = 0.0
var is_winding_up: bool = false
var locked_attack_direction: Vector2 = Vector2.ZERO

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_component: HealthComponent = $HealthComponent
@onready var aim_pivot: Node2D = $AimPivot
@onready var muzzle: Marker2D = $AimPivot/Muzzle
@onready var shoot_cooldown: Timer = $ShootCooldown
@onready var attack_audio: AudioStreamPlayer2D = $AttackAudio


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D
	shoot_cooldown.wait_time = attack_interval
	attack_audio.stream = COMBAT_FEEDBACK.create_synth_sound(
		480.0, 170.0, 0.14, 0.22
	)
	health_component.max_health = max_health
	health_component.reset_health()
	health_component.damaged.connect(_on_health_damaged)
	health_component.died.connect(_on_health_died)
	animated_sprite.self_modulate = Color(0.58, 0.78, 1.0, 1.0)
	begin_entry_grace()


func _physics_process(delta: float) -> void:
	attack_feedback_remaining = maxf(attack_feedback_remaining - delta, 0.0)
	attack_grace_remaining = maxf(attack_grace_remaining - delta, 0.0)

	if _process_knockback(delta):
		return

	if not is_instance_valid(player) or health_component.is_dead:
		_stop_moving()
		return
	if is_winding_up:
		velocity = Vector2.ZERO
		return

	var distance_to_player := global_position.distance_to(player.global_position)

	if distance_to_player > activation_distance:
		_stop_moving()
		return

	var aim_direction := global_position.direction_to(player.global_position)
	aim_pivot.rotation = aim_direction.angle()

	if distance_to_player < retreat_distance:
		velocity = -aim_direction * move_speed
	elif distance_to_player > preferred_distance + 40.0:
		velocity = aim_direction * move_speed
	else:
		velocity = Vector2.ZERO

	move_and_slide()
	_update_animation(aim_direction)

	if (
		distance_to_player <= attack_range
		and attack_grace_remaining <= 0.0
		and shoot_cooldown.is_stopped()
		and _has_line_of_sight()
	):
		_begin_attack()


func _stop_moving() -> void:
	velocity = Vector2.ZERO
	if attack_feedback_remaining <= 0.0:
		animated_sprite.play("idle")


func _update_animation(aim_direction: Vector2) -> void:
	if attack_feedback_remaining <= 0.0:
		if velocity == Vector2.ZERO:
			animated_sprite.play("idle")
		else:
			animated_sprite.play("walk")

	if abs(aim_direction.x) > 0.01:
		animated_sprite.flip_h = aim_direction.x < 0.0


func _has_line_of_sight() -> bool:
	var target_position := player.global_position + Vector2(0.0, 50.0)
	var query := PhysicsRayQueryParameters2D.create(
		muzzle.global_position,
		target_position,
		9,
		[get_rid()]
	)
	var result := get_world_2d().direct_space_state.intersect_ray(query)

	return not result.is_empty() and result.get("collider") == player


func begin_entry_grace(duration: float = -1.0) -> void:
	attack_grace_remaining = (
		entry_grace_duration if duration < 0.0 else maxf(duration, 0.0)
	)


func _begin_attack() -> void:
	if is_winding_up or not is_instance_valid(player) or health_component.is_dead:
		return

	is_winding_up = true
	velocity = Vector2.ZERO
	locked_attack_direction = muzzle.global_position.direction_to(
		player.global_position + Vector2(0.0, 50.0)
	)
	aim_pivot.rotation = locked_attack_direction.angle()
	_show_attack_telegraph()

	await get_tree().create_timer(attack_windup).timeout
	if not is_inside_tree() or health_component.is_dead:
		is_winding_up = false
		return

	shoot(locked_attack_direction)
	is_winding_up = false


func shoot(direction: Vector2 = Vector2.ZERO) -> void:
	var projectile := PROJECTILE_SCENE.instantiate() as Area2D
	var projectile_parent := get_tree().current_scene

	if projectile_parent == null:
		projectile_parent = get_parent()

	projectile_parent.add_child(projectile)
	projectile.global_position = muzzle.global_position
	projectile.set(
		"direction",
		direction.normalized()
		if direction != Vector2.ZERO
		else muzzle.global_transform.x.normalized()
	)
	projectile.set("damage", projectile_damage)
	projectile.set("speed", projectile_speed)
	shoot_cooldown.start()
	_show_shoot_feedback()


func _show_attack_telegraph() -> void:
	attack_feedback_remaining = attack_windup
	animated_sprite.play("attack")
	animated_sprite.modulate = Color(0.55, 0.82, 1.0, 1.0)
	COMBAT_FEEDBACK.spawn_impact_particles(
		get_tree(),
		muzzle.global_position,
		locked_attack_direction,
		Color(0.42, 0.9, 1.0, 0.9),
		6,
		"RangedAttackTelegraph"
	)


func _show_shoot_feedback() -> void:
	attack_feedback_remaining = 0.16
	animated_sprite.play("attack")
	animated_sprite.modulate = Color(0.45, 0.9, 1.0, 1.0)
	attack_audio.play()

	var shot_direction := muzzle.global_transform.x.normalized()
	COMBAT_FEEDBACK.spawn_impact_particles(
		get_tree(),
		muzzle.global_position,
		shot_direction,
		Color(0.3, 0.82, 1.0, 1.0),
		launch_particle_amount,
		"RangedLaunchParticles"
	)

	animated_sprite.position = -shot_direction * 7.0

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.14)
	tween.tween_property(
		animated_sprite,
		"position",
		Vector2.ZERO,
		0.14
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func take_damage(amount: int) -> bool:
	return health_component.take_damage(amount)


func apply_knockback(impulse: Vector2) -> void:
	knockback_velocity = impulse


func _process_knockback(delta: float) -> bool:
	if knockback_velocity.length_squared() < 1.0:
		knockback_velocity = Vector2.ZERO
		return false

	velocity = knockback_velocity
	move_and_slide()
	knockback_velocity = knockback_velocity.move_toward(
		Vector2.ZERO,
		knockback_deceleration * delta
	)
	animated_sprite.play("walk")
	return true


func _on_health_damaged(_amount: int, current_health: int) -> void:
	if current_health <= 0:
		return

	animated_sprite.modulate = Color(1.0, 0.3, 0.3)

	var tween := create_tween()
	tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.12)


func _on_health_died() -> void:
	died.emit()
	queue_free()
