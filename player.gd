extends CharacterBody2D
signal died

@export var speed: float = 250.0

@export_group("Sword Attack")
@export_range(1, 100, 1) var attack_damage: int = 1
@export_range(16.0, 256.0, 1.0) var attack_range: float = 90.0
@export_range(16.0, 160.0, 1.0) var attack_width: float = 56.0
@export_range(0.05, 3.0, 0.05) var attack_interval: float = 0.45
@export_range(0.05, 1.0, 0.01) var attack_active_duration: float = 0.12

var attack_active: bool = false
var hit_targets: Dictionary = {}

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var aim_pivot: Node2D = $AimPivot
@onready var sword_attack: Area2D = $SwordAttack
@onready var attack_collision: CollisionShape2D = (
	$SwordAttack/CollisionShape2D
)
@onready var attack_visual: Polygon2D = $SwordAttack/AttackVisual
@onready var attack_cooldown: Timer = $AttackCooldown
@onready var health_component: HealthComponent = $HealthComponent


func _ready() -> void:
	configure_sword_attack()
	sword_attack.body_entered.connect(_on_sword_attack_body_entered)
	health_component.damaged.connect(_on_health_damaged)
	health_component.died.connect(_on_health_died)

	print_health()


func _physics_process(_delta: float) -> void:
	if health_component.is_dead:
		return

	var direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	velocity = direction * speed
	move_and_slide()

	update_animation(direction)
	update_aim()
	handle_attack_input()


func update_animation(direction: Vector2) -> void:
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
	attack_cooldown.start()

	# Lock the hitbox to the direction selected at the start of the swing.
	sword_attack.rotation = aim_pivot.rotation
	attack_collision.set_deferred("disabled", false)
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
	body.take_damage(attack_damage)


func _on_sword_attack_body_entered(body: Node2D) -> void:
	try_damage_attack_target(body)


func show_attack_feedback() -> void:
	attack_visual.show()
	attack_visual.modulate = Color(1.0, 0.9, 0.35, 0.8)

	var tween := create_tween()
	tween.tween_property(
		attack_visual,
		"modulate:a",
		0.15,
		attack_active_duration
	)


func take_damage(amount: int) -> void:
	health_component.take_damage(amount)


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
		"Vida do Player: ",
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
	print("Player morreu!")

	await get_tree().create_timer(1.0).timeout
	get_tree().reload_current_scene()
