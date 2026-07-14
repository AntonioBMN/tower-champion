class_name Enemy
extends CharacterBody2D
signal died

@export var speed: float = 100.0
@export var contact_damage: int = 1

var player: Node2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_component: HealthComponent = $HealthComponent


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D
	health_component.damaged.connect(_on_health_damaged)
	health_component.died.connect(_on_health_died)


func _physics_process(_delta: float) -> void:
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
	if direction == Vector2.ZERO:
		animated_sprite.play("idle")
	else:
		animated_sprite.play("walk")

	if direction.x != 0.0:
		animated_sprite.flip_h = direction.x < 0.0


func damage_player_on_contact() -> void:
	for collision_index in get_slide_collision_count():
		var collision := get_slide_collision(collision_index)
		var collider := collision.get_collider() as Node

		if collider == null:
			continue

		if collider.is_in_group("player"):
			if collider.has_method("take_damage"):
				collider.take_damage(contact_damage)


func take_damage(amount: int) -> void:
	health_component.take_damage(amount)


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
