class_name FloorExit
extends Area2D

signal entered(body: Node2D)

var pulse_time: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	pulse_time += delta
	queue_redraw()


func _draw() -> void:
	var pulse := 1.0 + sin(pulse_time * 4.5) * 0.08
	var outer_color := Color(0.18, 0.92, 0.7, 0.35)
	var inner_color := Color(0.32, 1.0, 0.78, 0.9)
	var stair_color := Color(0.08, 0.2, 0.19, 1.0)

	draw_circle(Vector2.ZERO, 34.0 * pulse, outer_color)
	draw_arc(
		Vector2.ZERO,
		26.0 * pulse,
		0.0,
		TAU,
		40,
		inner_color,
		4.0,
		true
	)
	for step_index in range(4):
		var width := 30.0 - step_index * 5.0
		var y := -12.0 + step_index * 8.0
		draw_rect(
			Rect2(Vector2(-width * 0.5, y), Vector2(width, 5.0)),
			stair_color,
			true
		)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		entered.emit(body)
