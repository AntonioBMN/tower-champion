extends Node

signal display_configuration_changed

const DISPLAY_PROFILE = preload("res://ui/display/display_profile.gd")
const RESOLUTION_PRESETS: Array[Vector2i] = [
	Vector2i(960, 540),
	Vector2i(1024, 768),
	Vector2i(1152, 648),
	Vector2i(1280, 720),
	Vector2i(1280, 800),
	Vector2i(1366, 768),
	Vector2i(1600, 700),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]
const RESOLUTION_ASPECT_LABELS: Array[String] = [
	"16:9",
	"4:3",
	"16:9",
	"16:9",
	"16:10",
	"16:9",
	"ULTRAWIDE",
	"16:9",
	"16:9",
]

enum AspectMode {
	PROTECTED_16_9,
	EXPANDED,
}

enum ScalingMode {
	SMOOTH,
	INTEGER,
}

var aspect_mode := AspectMode.PROTECTED_16_9
var scaling_mode := ScalingMode.SMOOTH


func _ready() -> void:
	apply_display_profile()
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_min_size(
			DISPLAY_PROFILE.MINIMUM_WINDOW_SIZE
		)


func apply_display_profile() -> void:
	var window := get_window()
	if window == null:
		return

	window.content_scale_size = DISPLAY_PROFILE.DESIGN_SIZE
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = (
		Window.CONTENT_SCALE_ASPECT_KEEP
		if aspect_mode == AspectMode.PROTECTED_16_9
		else Window.CONTENT_SCALE_ASPECT_EXPAND
	)
	window.content_scale_stretch = (
		Window.CONTENT_SCALE_STRETCH_INTEGER
		if scaling_mode == ScalingMode.INTEGER
		else Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	)
	display_configuration_changed.emit()


func set_aspect_mode(value: AspectMode) -> void:
	if aspect_mode == value:
		return
	aspect_mode = value
	apply_display_profile()


func set_scaling_mode(value: ScalingMode) -> void:
	if scaling_mode == value:
		return
	scaling_mode = value
	apply_display_profile()


func get_gameplay_size() -> Vector2:
	return Vector2(DISPLAY_PROFILE.DESIGN_SIZE)


func get_physical_safe_rect(output_size: Vector2i) -> Rect2i:
	return DISPLAY_PROFILE.get_safe_rect(output_size)


func get_resolution_presets() -> Array[Vector2i]:
	return RESOLUTION_PRESETS.duplicate()


func get_resolution_label(index: int) -> String:
	if index < 0 or index >= RESOLUTION_PRESETS.size():
		return ""
	var resolution := RESOLUTION_PRESETS[index]
	return "%d x %d (%s)" % [
		resolution.x,
		resolution.y,
		RESOLUTION_ASPECT_LABELS[index],
	]


func find_closest_resolution_index(resolution: Vector2i) -> int:
	var closest_index := 0
	var closest_distance := INF
	for index in range(RESOLUTION_PRESETS.size()):
		var difference := RESOLUTION_PRESETS[index] - resolution
		var distance := difference.length_squared()
		if distance < closest_distance:
			closest_distance = distance
			closest_index = index
	return closest_index


func can_resize_window() -> bool:
	return (
		DisplayServer.get_name() != "headless"
		and not Engine.is_embedded_in_editor()
	)


func set_windowed_resolution(resolution: Vector2i) -> bool:
	if not can_resize_window():
		return false

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(resolution)
	var screen_index := DisplayServer.window_get_current_screen()
	var screen_position := DisplayServer.screen_get_position(screen_index)
	var screen_size := DisplayServer.screen_get_size(screen_index)
	DisplayServer.window_set_position(
		screen_position + (screen_size - resolution) / 2
	)
	display_configuration_changed.emit()
	return true
