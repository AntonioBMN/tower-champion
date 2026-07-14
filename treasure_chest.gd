class_name TreasureChest
extends Area2D

signal opened(chest: TreasureChest)

const COMBAT_FEEDBACK = preload("res://combat_feedback.gd")

var is_open: bool = false
var feedback_tween: Tween
var open_sound: AudioStreamWAV

@onready var prompt_label: Label = $PromptLabel
@onready var collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	open_sound = COMBAT_FEEDBACK.create_synth_sound(
		260.0, 720.0, 0.24, 0.08
	)
	body_entered.connect(_try_open)
	queue_redraw()


func _draw() -> void:
	var wood := Color(0.5, 0.25, 0.08, 1.0)
	var wood_light := Color(0.72, 0.39, 0.12, 1.0)
	var metal := Color(0.95, 0.7, 0.16, 1.0)
	var lid_offset := Vector2(0.0, -15.0) if is_open else Vector2.ZERO

	draw_rect(Rect2(Vector2(-30.0, -8.0), Vector2(60.0, 35.0)), wood, true)
	draw_rect(
		Rect2(Vector2(-31.0, -24.0) + lid_offset, Vector2(62.0, 19.0)),
		wood_light,
		true
	)
	draw_rect(Rect2(Vector2(-4.0, -8.0), Vector2(8.0, 18.0)), metal, true)
	draw_line(Vector2(-30.0, 2.0), Vector2(30.0, 2.0), metal, 3.0)


func _try_open(body: Node2D) -> bool:
	if is_open or not body.is_in_group("player"):
		return false

	if not body.has_method("spend_key") or not body.spend_key():
		_show_feedback("PRECISA DE 1 CHAVE", Color(1.0, 0.42, 0.28, 1.0))
		return false

	is_open = true
	monitoring = false
	collision.set_deferred("disabled", true)
	prompt_label.text = "ABERTO"
	prompt_label.modulate = Color(0.55, 0.92, 0.62, 1.0)
	queue_redraw()
	COMBAT_FEEDBACK.spawn_impact_particles(
		get_tree(), global_position, Vector2.UP,
		Color(1.0, 0.72, 0.2, 1.0), 20, "ChestOpenParticles"
	)
	COMBAT_FEEDBACK.play_one_shot_sound(
		get_tree(), global_position, open_sound, -3.0, "ChestOpenAudio"
	)
	opened.emit(self)
	return true


func _show_feedback(message: String, color: Color) -> void:
	if is_instance_valid(feedback_tween):
		feedback_tween.kill()

	prompt_label.text = message
	prompt_label.modulate = color
	feedback_tween = create_tween()
	feedback_tween.tween_interval(1.0)
	feedback_tween.tween_callback(func() -> void:
		if not is_open:
			prompt_label.text = "BAU: 1 CHAVE"
			prompt_label.modulate = Color(1.0, 0.82, 0.42, 1.0)
	)
