extends CharacterBody2D
signal died

@export var speed: float = 250.0

@export_group("Sword Attack")
@export_range(1, 1000, 1) var attack_damage: int = 20
@export_range(16.0, 256.0, 1.0) var attack_range: float = 90.0
@export_range(16.0, 160.0, 1.0) var attack_width: float = 56.0
@export_range(0.05, 3.0, 0.05) var attack_interval: float = 0.45
@export_range(0.05, 1.0, 0.01) var attack_active_duration: float = 0.12

@export_group("Combat Feel")
@export_range(0.0, 1200.0, 10.0) var attack_knockback: float = 430.0
@export_range(0.0, 0.2, 0.005) var hit_stop_duration: float = 0.045
@export_range(0.01, 1.0, 0.01) var hit_stop_time_scale: float = 0.08
@export_range(1, 64, 1) var impact_particle_amount: int = 14
@export_range(0.0, 1200.0, 10.0) var received_knockback_deceleration: float = 1500.0
@export_range(0.0, 0.2, 0.005) var received_hit_stop_duration: float = 0.035
@export_range(0.01, 1.0, 0.01) var received_hit_stop_time_scale: float = 0.14

var attack_active: bool = false
var hit_targets: Dictionary = {}
var hit_stop_triggered: bool = false
var hit_stop_active: bool = false
var previous_time_scale: float = 1.0
var received_knockback_velocity: Vector2 = Vector2.ZERO

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var aim_pivot: Node2D = $AimPivot
@onready var sword_attack: Area2D = $SwordAttack
@onready var attack_collision: CollisionShape2D = (
	$SwordAttack/CollisionShape2D
)
@onready var attack_visual: Polygon2D = $SwordAttack/AttackVisual
@onready var attack_cooldown: Timer = $AttackCooldown
@onready var health_component: HealthComponent = $HealthComponent
@onready var relic_component: RelicComponent = $RelicComponent
@onready var run_inventory: RunInventory = $RunInventory
@onready var swing_audio: AudioStreamPlayer2D = $SwingAudio
@onready var hit_audio: AudioStreamPlayer2D = $HitAudio


func _ready() -> void:
	# Each player needs its own hitbox so range relics do not modify the
	# shared resource used by a new run.
	attack_collision.shape = attack_collision.shape.duplicate()
	configure_sword_attack()
	sword_attack.body_entered.connect(_on_sword_attack_body_entered)
	health_component.damaged.connect(_on_health_damaged)
	health_component.died.connect(_on_health_died)
	_configure_combat_audio()

	print_health()


func _physics_process(delta: float) -> void:
	if health_component.is_dead:
		return

	var direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	velocity = direction * speed + received_knockback_velocity
	move_and_slide()
	received_knockback_velocity = received_knockback_velocity.move_toward(
		Vector2.ZERO,
		received_knockback_deceleration * delta
	)

	update_animation(direction)
	update_aim()
	handle_attack_input()


func update_animation(direction: Vector2) -> void:
	if attack_active:
		return

	if direction == Vector2.ZERO:
		animated_sprite.play("idle")
	else:
		animated_sprite.play("walk")


func update_aim() -> void:
	var mouse_position := get_global_mouse_position()
	var aim_direction := mouse_position - global_position

	aim_pivot.look_at(mouse_position)

	if abs(aim_direction.x) > 0.1:
		animated_sprite.flip_h = aim_direction.x < 0.0


func configure_sword_attack() -> void:
	attack_cooldown.wait_time = attack_interval

	var attack_shape := attack_collision.shape as RectangleShape2D
	attack_shape.size = Vector2(attack_range, attack_width)
	attack_collision.position = Vector2(attack_range * 0.5, 0.0)

	var half_width := attack_width * 0.5
	attack_visual.polygon = PackedVector2Array([
		Vector2.ZERO,
		Vector2(attack_range - 12.0, -half_width),
		Vector2(attack_range, 0.0),
		Vector2(attack_range - 12.0, half_width),
	])


func handle_attack_input() -> void:
	if (
		Input.is_action_pressed("attack")
		and attack_cooldown.is_stopped()
		and not attack_active
	):
		perform_sword_attack()


func perform_sword_attack() -> void:
	attack_active = true
	hit_targets.clear()
	hit_stop_triggered = false
	attack_cooldown.start()

	# Lock the hitbox to the direction selected at the start of the swing.
	sword_attack.rotation = aim_pivot.rotation
	attack_collision.set_deferred("disabled", false)
	animated_sprite.play("attack")
	swing_audio.play()
	show_attack_feedback()

	await get_tree().physics_frame

	for body in sword_attack.get_overlapping_bodies():
		try_damage_attack_target(body)

	await get_tree().create_timer(attack_active_duration).timeout

	attack_collision.set_deferred("disabled", true)
	attack_active = false
	attack_visual.hide()


func try_damage_attack_target(body: Node) -> void:
	if not attack_active or not is_instance_valid(body):
		return

	if not body.is_in_group("enemies") or not body.has_method("take_damage"):
		return

	var target_id := body.get_instance_id()

	if hit_targets.has(target_id):
		return

	hit_targets[target_id] = true
	var damage_applied: Variant = body.take_damage(attack_damage)

	if damage_applied is bool and not damage_applied:
		return

	var knockback_direction := global_position.direction_to(body.global_position)
	if knockback_direction == Vector2.ZERO:
		knockback_direction = Vector2.RIGHT.rotated(sword_attack.rotation)

	if body.has_method("apply_knockback"):
		body.apply_knockback(knockback_direction * attack_knockback)

	_spawn_hit_particles(
		body.global_position + Vector2(0.0, 45.0),
		knockback_direction
	)
	hit_audio.global_position = body.global_position + Vector2(0.0, 45.0)
	hit_audio.play()

	if not hit_stop_triggered:
		hit_stop_triggered = true
		_apply_hit_stop()


func _on_sword_attack_body_entered(body: Node2D) -> void:
	try_damage_attack_target(body)


func show_attack_feedback() -> void:
	attack_visual.show()
	attack_visual.modulate = Color(1.0, 0.9, 0.35, 0.8)
	attack_visual.rotation = deg_to_rad(-52.0)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(
		attack_visual,
		"rotation",
		deg_to_rad(52.0),
		attack_active_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		attack_visual,
		"modulate:a",
		0.08,
		attack_active_duration
	)


func _spawn_hit_particles(
	impact_position: Vector2,
	impact_direction: Vector2
) -> void:
	var particles := CPUParticles2D.new()
	particles.name = "SwordHitParticles"
	particles.top_level = true
	particles.global_position = impact_position
	particles.z_index = 20
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = impact_particle_amount
	particles.lifetime = 0.24
	particles.direction = impact_direction
	particles.spread = 68.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 95.0
	particles.initial_velocity_max = 230.0
	particles.scale_amount_min = 1.8
	particles.scale_amount_max = 3.8
	particles.color = Color(1.0, 0.72, 0.18, 1.0)
	particles.finished.connect(particles.queue_free)

	var effect_parent := get_tree().current_scene
	if effect_parent == null:
		effect_parent = get_parent()
	effect_parent.add_child(particles)
	particles.restart()


func _apply_hit_stop(
	duration: float = hit_stop_duration,
	time_scale: float = hit_stop_time_scale
) -> void:
	if hit_stop_active or duration <= 0.0:
		return

	hit_stop_active = true
	previous_time_scale = Engine.time_scale
	Engine.time_scale = time_scale
	await get_tree().create_timer(
		duration,
		true,
		false,
		true
	).timeout
	_restore_time_scale()


func _restore_time_scale() -> void:
	if not hit_stop_active:
		return

	Engine.time_scale = previous_time_scale
	hit_stop_active = false


func _configure_combat_audio() -> void:
	swing_audio.stream = _create_synth_sound(620.0, 180.0, 0.11, 0.18)
	hit_audio.stream = _create_synth_sound(150.0, 70.0, 0.09, 0.48)


func _create_synth_sound(
	start_frequency: float,
	end_frequency: float,
	duration: float,
	noise_mix: float
) -> AudioStreamWAV:
	const MIX_RATE := 22050
	var sample_count := maxi(1, int(duration * MIX_RATE))
	var audio_data := PackedByteArray()
	audio_data.resize(sample_count * 2)
	var phase := 0.0

	for sample_index in range(sample_count):
		var progress := float(sample_index) / float(sample_count)
		var frequency := lerpf(start_frequency, end_frequency, progress)
		phase += TAU * frequency / MIX_RATE
		var noise := sin(float(sample_index) * 12.9898) * 43758.5453
		noise = (noise - floor(noise)) * 2.0 - 1.0
		var envelope := pow(1.0 - progress, 2.0)
		var waveform := lerpf(sin(phase), noise, noise_mix)
		var sample_value := int(
			clampf(waveform * envelope * 0.42, -1.0, 1.0) * 32767.0
		)
		audio_data.encode_s16(sample_index * 2, sample_value)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = audio_data
	return stream


func take_damage(amount: int) -> bool:
	var damage_applied := health_component.take_damage(amount)
	if damage_applied:
		_apply_hit_stop(
			received_hit_stop_duration,
			received_hit_stop_time_scale
		)
	return damage_applied


func apply_knockback(impulse: Vector2) -> void:
	received_knockback_velocity = impulse


func collect_relic(relic_id: String) -> bool:
	return relic_component.collect_relic(relic_id)


func add_keys(amount: int = 1) -> bool:
	return run_inventory.add_keys(amount)


func spend_key() -> bool:
	return run_inventory.spend_key()


func get_key_count() -> int:
	return run_inventory.keys


func apply_relic_effects(effects: Dictionary) -> void:
	attack_damage += int(effects.get("attack_damage_add", 0))
	speed *= float(effects.get("speed_multiplier", 1.0))
	attack_range += float(effects.get("attack_range_add", 0.0))
	attack_width += float(effects.get("attack_width_add", 0.0))

	var max_health_add := int(effects.get("max_health_add", 0))
	var heal_amount := int(effects.get("heal_amount", 0))
	if max_health_add > 0:
		health_component.increase_max_health(max_health_add, heal_amount)
	elif heal_amount > 0:
		health_component.heal(heal_amount)

	configure_sword_attack()


func _on_health_damaged(_amount: int, current_health: int) -> void:
	print_health()

	if current_health > 0:
		flash_damage()


func flash_damage() -> void:
	animated_sprite.modulate = Color(1.0, 0.25, 0.25)

	var tween := create_tween()
	tween.tween_property(
		animated_sprite,
		"modulate",
		Color.WHITE,
		0.15
	)


func print_health() -> void:
	print(
		"Player health: ",
		health_component.current_health,
		"/",
		health_component.max_health
	)


func _on_health_died() -> void:
	velocity = Vector2.ZERO
	attack_active = false
	attack_collision.set_deferred("disabled", true)
	attack_visual.hide()

	set_collision_layer_value(1, false)
	set_collision_mask_value(3, false)
	set_collision_mask_value(4, false)

	animated_sprite.stop()
	animated_sprite.modulate = Color(0.35, 0.35, 0.35)

	died.emit()
	print("Player died.")

	await get_tree().create_timer(1.0).timeout
	get_tree().reload_current_scene()


func _exit_tree() -> void:
	_restore_time_scale()
