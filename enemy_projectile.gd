class_name EnemyProjectile
extends Area2D

@export_range(100.0, 1200.0, 10.0) var speed: float = 520.0
@export_range(1, 100, 1) var damage: int = 1
@export_range(0.2, 5.0, 0.1) var max_lifetime: float = 2.0

var direction: Vector2 = Vector2.RIGHT
var lifetime: float


func _ready() -> void:
	lifetime = max_lifetime
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
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)

	queue_free()
