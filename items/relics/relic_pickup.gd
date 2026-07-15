class_name RelicPickup
extends Area2D

signal collected(relic_id: String)

const CATALOG = preload("res://items/relics/relic_catalog.gd")
const COMBAT_FEEDBACK = preload("res://combat/combat_feedback.gd")

@export var relic_id: String = "crimson_blade"

var relic_data: Dictionary = {}
var pulse_time: float = 0.0
var collect_sound: AudioStreamWAV

@onready var name_label: Label = $NameLabel
@onready var effect_label: Label = $EffectLabel


func configure(new_relic_id: String) -> void:
	relic_id = new_relic_id
	relic_data = CATALOG.get_relic(relic_id)
	queue_redraw()


func _ready() -> void:
	if relic_data.is_empty():
		relic_data = CATALOG.get_relic(relic_id)

	if relic_data.is_empty():
		push_error("Unknown relic: " + relic_id)
		queue_free()
		return

	name_label.text = tr(relic_data["name_key"])
	effect_label.text = tr(relic_data["description_key"])
	collect_sound = COMBAT_FEEDBACK.create_synth_sound(
		520.0, 880.0, 0.18, 0.08
	)
	body_entered.connect(_try_collect)


func _process(delta: float) -> void:
	pulse_time += delta
	queue_redraw()


func _draw() -> void:
	if relic_data.is_empty():
		return

	var pulse := 1.0 + sin(pulse_time * 4.0) * 0.08
	var relic_color: Color = relic_data["color"]
	var diamond := PackedVector2Array([
		Vector2(0.0, -22.0) * pulse,
		Vector2(18.0, 0.0) * pulse,
		Vector2(0.0, 22.0) * pulse,
		Vector2(-18.0, 0.0) * pulse,
	])

	draw_circle(Vector2(0.0, 22.0), 28.0, Color(0.05, 0.06, 0.1, 0.8))
	draw_rect(
		Rect2(Vector2(-24.0, 18.0), Vector2(48.0, 14.0)),
		Color(0.2, 0.22, 0.3, 1.0),
		true
	)
	draw_colored_polygon(diamond, relic_color)
	draw_polyline(
		PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]),
		Color(1.0, 1.0, 1.0, 0.8),
		2.0,
		true
	)
	draw_circle(Vector2(-5.0, -6.0) * pulse, 3.0, Color(1, 1, 1, 0.72))


func _try_collect(body: Node2D) -> bool:
	if (
		not body.is_in_group("player")
		or not body.has_method("collect_relic")
	):
		return false

	if not body.collect_relic(relic_id):
		return false

	COMBAT_FEEDBACK.spawn_impact_particles(
		get_tree(),
		global_position,
		Vector2.UP,
		relic_data["color"],
		20,
		"RelicCollectParticles"
	)
	COMBAT_FEEDBACK.play_one_shot_sound(
		get_tree(),
		global_position,
		collect_sound,
		-4.0,
		"RelicCollectAudio"
	)
	collected.emit(relic_id)
	queue_free()
	return true
