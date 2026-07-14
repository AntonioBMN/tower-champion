class_name RangedEnemy
extends CharacterBody2D

signal died

const PROJECTILE_SCENE: PackedScene = preload("res://enemy_projectile.tscn")

@export_group("Stats")
@export_range(1, 100, 1) var max_health: int = 1

@export_group("Movement")
@export_range(10.0, 500.0, 5.0) var move_speed: float = 85.0
@export_range(80.0, 500.0, 10.0) var retreat_distance: float = 220.0
@export_range(120.0, 700.0, 10.0) var preferred_distance: float = 340.0
@export_range(200.0, 1200.0, 25.0) var activation_distance: float = 750.0

@export_group("Ranged Attack")
@export_range(1, 100, 1) var projectile_damage: int = 1
@export_range(100.0, 1200.0, 10.0) var projectile_speed: float = 520.0
@export_range(0.2, 5.0, 0.05) var attack_interval: float = 1.15
@export_range(100.0, 1000.0, 10.0) var attack_range: float = 580.0

var player: Node2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_component: HealthComponent = $HealthComponent
@onready var aim_pivot: Node2D = $AimPivot
@onready var muzzle: Marker2D = $AimPivot/Muzzle
@onready var shoot_cooldown: Timer = $ShootCooldown


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D
	shoot_cooldown.wait_time = attack_interval
	health_component.max_health = max_health
	health_component.reset_health()
	health_component.damaged.connect(_on_health_damaged)
	health_component.died.connect(_on_health_died)
	animated_sprite.self_modulate = Color(0.58, 0.78, 1.0, 1.0)


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player) or health_component.is_dead:
		_stop_moving()
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
		and shoot_cooldown.is_stopped()
		and _has_line_of_sight()
	):
		shoot()


func _stop_moving() -> void:
	velocity = Vector2.ZERO
	animated_sprite.play("idle")


func _update_animation(aim_direction: Vector2) -> void:
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


func shoot() -> void:
	var projectile := PROJECTILE_SCENE.instantiate() as Area2D
	var projectile_parent := get_tree().current_scene

	if projectile_parent == null:
		projectile_parent = get_parent()

	projectile_parent.add_child(projectile)
	projectile.global_position = muzzle.global_position
	projectile.set("direction", muzzle.global_transform.x.normalized())
	projectile.set("damage", projectile_damage)
	projectile.set("speed", projectile_speed)
	shoot_cooldown.start()
	_show_shoot_feedback()


func _show_shoot_feedback() -> void:
	animated_sprite.modulate = Color(0.45, 0.9, 1.0, 1.0)

	var tween := create_tween()
	tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.14)


func take_damage(amount: int) -> void:
	health_component.take_damage(amount)


func _on_health_damaged(_amount: int, current_health: int) -> void:
	if current_health <= 0:
		return

	animated_sprite.modulate = Color(1.0, 0.3, 0.3)

	var tween := create_tween()
	tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.12)


func _on_health_died() -> void:
	died.emit()
	queue_free()
