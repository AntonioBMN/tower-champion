class_name HealthPickup
extends Area2D

@export_range(1, 1000, 1) var heal_amount: int = 18

var pulse_time: float = 0.0


func _ready() -> void:
	body_entered.connect(_try_collect)


func _physics_process(delta: float) -> void:
	pulse_time += delta
	queue_redraw()

	# A pickup at full health remains available and can be collected later.
	for body in get_overlapping_bodies():
		if _try_collect(body):
			return


func _draw() -> void:
	var pulse := 1.0 + sin(pulse_time * 5.0) * 0.08
	var heart_color := Color(0.95, 0.12, 0.22, 1.0)
	var highlight_color := Color(1.0, 0.48, 0.55, 1.0)

	draw_circle(Vector2(-6.0, -4.0) * pulse, 7.5 * pulse, heart_color)
	draw_circle(Vector2(6.0, -4.0) * pulse, 7.5 * pulse, heart_color)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13.0, -1.0) * pulse,
		Vector2(13.0, -1.0) * pulse,
		Vector2(0.0, 15.0) * pulse,
	]), heart_color)
	draw_circle(Vector2(-6.0, -6.0) * pulse, 2.5 * pulse, highlight_color)


func _try_collect(body: Node2D) -> bool:
	if not body.is_in_group("player"):
		return false

	var health := body.get_node_or_null("HealthComponent") as HealthComponent

	if health == null or not health.heal(heal_amount):
		return false

	queue_free()
	return true
