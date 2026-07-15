class_name TreasureChest
extends Area2D

signal opened(chest: TreasureChest)

const COMBAT_FEEDBACK = preload("res://combat/combat_feedback.gd")
const FRAME_SIZE := Vector2i(32, 32)
const OPENING_FRAME_COUNT := 4

enum ChestTier {
	WOOD,
	SILVER,
	RED,
}

const TIER_DATA := {
	ChestTier.WOOD: {
		"atlas_origin": Vector2i(96, 128),
		"name_key": "CHEST_TIER_WOOD",
		"color": Color(0.84, 0.56, 0.28, 1.0),
	},
	ChestTier.SILVER: {
		"atlas_origin": Vector2i(192, 128),
		"name_key": "CHEST_TIER_SILVER",
		"color": Color(0.78, 0.86, 0.96, 1.0),
	},
	ChestTier.RED: {
		"atlas_origin": Vector2i(0, 0),
		"name_key": "CHEST_TIER_RED",
		"color": Color(1.0, 0.3, 0.24, 1.0),
	},
}

@export var chest_tier: ChestTier = ChestTier.WOOD
@export_range(0.01, 0.5, 0.01) var opening_frame_duration: float = 0.12

var is_open: bool = false
var feedback_tween: Tween
var open_sound: AudioStreamWAV

@onready var prompt_label: Label = $PromptLabel
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var chest_sprite: Sprite2D = $ChestSprite


func configure(tier: ChestTier) -> void:
	chest_tier = tier
	if is_node_ready():
		_refresh_tier_display()


func _ready() -> void:
	_refresh_tier_display()
	open_sound = COMBAT_FEEDBACK.create_synth_sound(
		260.0, 720.0, 0.24, 0.08
	)
	body_entered.connect(_try_open)


func _refresh_tier_display() -> void:
	var tier_data: Dictionary = TIER_DATA[chest_tier]
	_set_opening_frame(OPENING_FRAME_COUNT - 1 if is_open else 0)
	prompt_label.text = tr("CHEST_PROMPT") % tr(tier_data["name_key"])
	prompt_label.modulate = tier_data["color"]


func _set_opening_frame(frame_index: int) -> void:
	var origin: Vector2i = TIER_DATA[chest_tier]["atlas_origin"]
	chest_sprite.region_rect = Rect2(
		origin + Vector2i(0, FRAME_SIZE.y * frame_index),
		FRAME_SIZE
	)


func _play_opening_animation() -> void:
	var tween := create_tween()
	for frame_index in range(1, OPENING_FRAME_COUNT):
		tween.tween_interval(opening_frame_duration)
		tween.tween_callback(_set_opening_frame.bind(frame_index))


func _try_open(body: Node2D) -> bool:
	if is_open or not body.is_in_group("player"):
		return false

	if not body.has_method("spend_key") or not body.spend_key():
		_show_feedback(tr("CHEST_NEEDS_KEY"), Color(1.0, 0.42, 0.28, 1.0))
		return false

	is_open = true
	monitoring = false
	collision.set_deferred("disabled", true)
	prompt_label.text = tr("CHEST_OPENED")
	prompt_label.modulate = TIER_DATA[chest_tier]["color"]
	_play_opening_animation()
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
			_refresh_tier_display()
	)


func get_tier_name_key() -> String:
	return TIER_DATA[chest_tier]["name_key"]


func get_atlas_origin() -> Vector2i:
	return TIER_DATA[chest_tier]["atlas_origin"]
