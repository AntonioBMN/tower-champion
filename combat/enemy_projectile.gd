class_name EnemyProjectile
extends Area2D

const COMBAT_FEEDBACK = preload("res://combat/combat_feedback.gd")

@export_range(100.0, 1200.0, 10.0) var speed: float = 520.0
@export_range(1, 1000, 1) var damage: int = 10
@export_range(0.2, 5.0, 0.1) var max_lifetime: float = 2.0
@export_range(0.0, 1000.0, 10.0) var impact_knockback: float = 260.0
@export_range(1, 48, 1) var impact_particle_amount: int = 12

var direction: Vector2 = Vector2.RIGHT
var lifetime: float
var impact_sound: AudioStreamWAV


func _ready() -> void:
	lifetime = max_lifetime
	impact_sound = COMBAT_FEEDBACK.create_synth_sound(
		190.0, 65.0, 0.1, 0.42
	)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += direction.normalized() * speed * delta
	lifetime -= delta

	if lifetime <= 0.0:
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 9.0, Color(0.2, 0.03, 0.08, 0.9))
	draw_circle(Vector2.ZERO, 6.0, Color(1.0, 0.22, 0.42, 1.0))


func _on_body_entered(body: Node2D) -> void:
	var impact_direction := direction.normalized()
	var damage_applied := false

	if body.is_in_group("player") and body.has_method("take_damage"):
		var damage_result: Variant = body.take_damage(damage)
		damage_applied = damage_result if damage_result is bool else true

		if damage_applied and body.has_method("apply_knockback"):
			body.apply_knockback(impact_direction * impact_knockback)

	if damage_applied:
		COMBAT_FEEDBACK.spawn_impact_particles(
			get_tree(),
			global_position,
			impact_direction,
			Color(1.0, 0.18, 0.42, 1.0),
			impact_particle_amount,
			"EnemyProjectileHitParticles"
		)
		COMBAT_FEEDBACK.play_one_shot_sound(
			get_tree(),
			global_position,
			impact_sound,
			-5.0,
			"EnemyProjectileHitAudio"
		)

	queue_free()
