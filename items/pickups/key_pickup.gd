class_name KeyPickup
extends Area2D

signal collected(amount: int)

const COMBAT_FEEDBACK = preload("res://combat/combat_feedback.gd")

@export_range(1, 10, 1) var key_amount: int = 1

var pulse_time: float = 0.0
var collect_sound: AudioStreamWAV


func _ready() -> void:
	collect_sound = COMBAT_FEEDBACK.create_synth_sound(
		660.0, 1040.0, 0.13, 0.05
	)
	body_entered.connect(_try_collect)


func _process(delta: float) -> void:
	pulse_time += delta
	queue_redraw()


func _draw() -> void:
	var pulse := 1.0 + sin(pulse_time * 5.0) * 0.07
	var key_color := Color(1.0, 0.78, 0.18, 1.0)
	var dark_color := Color(0.45, 0.27, 0.05, 1.0)
	draw_circle(Vector2(-9.0, 0.0) * pulse, 9.0 * pulse, key_color)
	draw_circle(Vector2(-9.0, 0.0) * pulse, 4.0 * pulse, dark_color)
	draw_rect(
		Rect2(Vector2(-1.0, -3.5) * pulse, Vector2(25.0, 7.0) * pulse),
		key_color,
		true
	)
	draw_rect(
		Rect2(Vector2(14.0, 2.0) * pulse, Vector2(5.0, 8.0) * pulse),
		key_color,
		true
	)
	draw_rect(
		Rect2(Vector2(21.0, 2.0) * pulse, Vector2(5.0, 6.0) * pulse),
		key_color,
		true
	)


func _try_collect(body: Node2D) -> bool:
	if not body.is_in_group("player") or not body.has_method("add_keys"):
		return false

	if not body.add_keys(key_amount):
		return false

	COMBAT_FEEDBACK.spawn_impact_particles(
		get_tree(), global_position, Vector2.UP,
		Color(1.0, 0.78, 0.18, 1.0), 12, "KeyCollectParticles"
	)
	COMBAT_FEEDBACK.play_one_shot_sound(
		get_tree(), global_position, collect_sound, -5.0, "KeyCollectAudio"
	)
	collected.emit(key_amount)
	queue_free()
	return true
