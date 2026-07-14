class_name Projectile
extends Area2D

@export var speed: float = 650.0
@export var max_lifetime: float = 1.5
@export var damage: int = 1


var direction: Vector2 = Vector2.RIGHT
var lifetime: float


func _ready() -> void:
	lifetime = max_lifetime
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

	lifetime -= delta

	if lifetime <= 0.0:
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 6.0, Color.ORANGE)


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)

	queue_free()
