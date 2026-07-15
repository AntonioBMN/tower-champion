extends Control

@export var icon_color := Color(1.0, 0.78, 0.18, 1.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var ring_center := Vector2(7.0, 7.0)
	draw_arc(ring_center, 5.0, 0.0, TAU, 20, icon_color, 2.5, true)
	draw_line(Vector2(10.5, 10.5), Vector2(21.0, 21.0), icon_color, 3.0, true)
	draw_line(Vector2(16.0, 16.0), Vector2(19.0, 13.0), icon_color, 2.5, true)
	draw_line(Vector2(19.0, 19.0), Vector2(22.0, 16.0), icon_color, 2.5, true)
