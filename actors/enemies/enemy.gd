class_name Enemy
extends CharacterBody2D
signal died

const COMBAT_FEEDBACK = preload("res://combat/combat_feedback.gd")

@export var speed: float = 100.0
@export_range(1, 1000, 1) var contact_damage: int = 12
@export_range(0.2, 3.0, 0.05) var attack_interval: float = 0.75
@export_group("Combat Feel")
@export_range(100.0, 4000.0, 50.0) var knockback_deceleration: float = 1800.0
@export_range(0.0, 1000.0, 10.0) var contact_knockback: float = 300.0
@export_range(1, 48, 1) var impact_particle_amount: int = 11

var player: Node2D
var knockback_velocity: Vector2 = Vector2.ZERO
var attack_feedback_remaining: float = 0.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_component: HealthComponent = $HealthComponent
@onready var attack_cooldown: Timer = $AttackCooldown
@onready var attack_audio: AudioStreamPlayer2D = $AttackAudio
@onready var hit_audio: AudioStreamPlayer2D = $HitAudio


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D
	health_component.damaged.connect(_on_health_damaged)
	health_component.died.connect(_on_health_died)
	attack_cooldown.wait_time = attack_interval
	attack_audio.stream = COMBAT_FEEDBACK.create_synth_sound(
		210.0, 105.0, 0.12, 0.32
	)
	hit_audio.stream = COMBAT_FEEDBACK.create_synth_sound(
		125.0, 58.0, 0.1, 0.52
	)


func _physics_process(delta: float) -> void:
	attack_feedback_remaining = maxf(attack_feedback_remaining - delta, 0.0)

	if _process_knockback(delta):
		return

	if not is_instance_valid(player):
		velocity = Vector2.ZERO
		animated_sprite.play("idle")
		return

	var direction := global_position.direction_to(player.global_position)

	velocity = direction * speed
	move_and_slide()
	damage_player_on_contact()

	update_animation(direction)


func update_animation(direction: Vector2) -> void:
	if attack_feedback_remaining > 0.0:
		return

	if direction == Vector2.ZERO:
		animated_sprite.play("idle")
	else:
		animated_sprite.play("walk")

	if direction.x != 0.0:
		animated_sprite.flip_h = direction.x < 0.0


func damage_player_on_contact() -> void:
	if not attack_cooldown.is_stopped():
		return

	for collision_index in get_slide_collision_count():
		var collision := get_slide_collision(collision_index)
		var collider := collision.get_collider() as Node

		if collider == null:
			continue

		if collider.is_in_group("player"):
			if _deal_contact_damage(collider):
				return


func _deal_contact_damage(target: Node2D) -> bool:
	if (
		not is_instance_valid(target)
		or not target.has_method("take_damage")
		or not attack_cooldown.is_stopped()
	):
		return false

	var damage_applied: Variant = target.take_damage(contact_damage)
	if damage_applied is bool and not damage_applied:
		return false

	attack_cooldown.start()
	attack_feedback_remaining = 0.16
	animated_sprite.play("attack")
	attack_audio.play()
	hit_audio.global_position = target.global_position + Vector2(0.0, 45.0)
	hit_audio.play()

	var impact_direction := global_position.direction_to(target.global_position)
	if impact_direction == Vector2.ZERO:
		impact_direction = Vector2.RIGHT

	if target.has_method("apply_knockback"):
		target.apply_knockback(impact_direction * contact_knockback)

	COMBAT_FEEDBACK.spawn_impact_particles(
		get_tree(),
		target.global_position + Vector2(0.0, 45.0),
		impact_direction,
		Color(1.0, 0.28, 0.16, 1.0),
		impact_particle_amount,
		"EnemyMeleeHitParticles"
	)
	return true


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
	if current_health > 0:
		flash_damage()


func flash_damage() -> void:
	animated_sprite.modulate = Color(1.0, 0.3, 0.3)

	var tween := create_tween()
	tween.tween_property(
		animated_sprite,
		"modulate",
		Color.WHITE,
		0.12
	)


func _on_health_died() -> void:
	died.emit()
	queue_free()
