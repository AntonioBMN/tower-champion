extends CharacterBody2D

const PROJECTILE_SCENE: PackedScene = preload("res://projectile.tscn")

@export var speed: float = 250.0
@export var max_health: int = 5

var current_health: int
var is_invulnerable: bool = false
var is_dead: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var aim_pivot: Node2D = $AimPivot
@onready var muzzle: Marker2D = $AimPivot/Muzzle
@onready var shoot_cooldown: Timer = $ShootCooldown
@onready var invulnerability_timer: Timer = $InvulnerabilityTimer


func _ready() -> void:
	current_health = max_health
	invulnerability_timer.timeout.connect(
		_on_invulnerability_timer_timeout
	)

	print_health()


func _physics_process(_delta: float) -> void:
	if is_dead:
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
	handle_shooting()


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


func handle_shooting() -> void:
	if Input.is_action_pressed("shoot") and shoot_cooldown.is_stopped():
		shoot()


func shoot() -> void:
	var projectile := PROJECTILE_SCENE.instantiate() as Projectile

	get_tree().current_scene.add_child(projectile)

	projectile.global_position = muzzle.global_position
	projectile.direction = Vector2.RIGHT.rotated(
		aim_pivot.global_rotation
	)

	shoot_cooldown.start()


func take_damage(amount: int) -> void:
	if is_invulnerable or is_dead:
		return

	current_health -= amount
	current_health = maxi(current_health, 0)

	print_health()

	if current_health <= 0:
		die()
		return

	start_invulnerability()
	flash_damage()


func start_invulnerability() -> void:
	is_invulnerable = true
	invulnerability_timer.start()


func flash_damage() -> void:
	animated_sprite.modulate = Color(1.0, 0.25, 0.25)

	var tween := create_tween()
	tween.tween_property(
		animated_sprite,
		"modulate",
		Color.WHITE,
		0.15
	)


func _on_invulnerability_timer_timeout() -> void:
	is_invulnerable = false


func print_health() -> void:
	print("Vida do Player: ", current_health, "/", max_health)


func die() -> void:
	is_dead = true
	velocity = Vector2.ZERO

	set_collision_layer_value(1, false)
	set_collision_mask_value(3, false)
	set_collision_mask_value(4, false)

	animated_sprite.stop()
	animated_sprite.modulate = Color(0.35, 0.35, 0.35)

	print("Player morreu!")

	await get_tree().create_timer(1.0).timeout
	get_tree().reload_current_scene()
